import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/book_shelf_screen.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/child_profiles.dart';

import 'reading_test_helpers.dart';
import 'test_helpers.dart';

/// One family shelf: books are imported once and given to children, each of
/// whom keeps their own place in them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final alice = File('assets/books/alice_in_wonderland.epub');

  Directory tempRoot() {
    final root = Directory.systemTemp.createTempSync('book-shelf-test-');
    addTearDown(() => root.deleteSync(recursive: true));
    return root;
  }

  test('a book is on the shelves of the children it is given to', () async {
    SharedPreferences.setMockInitialValues({});
    final root = tempRoot();
    final shelf = BookShelf(root: root);
    final book = await shelf.add(
      fileName: 'alice.epub',
      bytes: alice.readAsBytesSync(),
      title: 'Alice',
      readers: ['A', 'B'],
    );
    final a = BookLibrary('A', root: root), b = BookLibrary('B', root: root);
    expect((await a.load()).single.id, book.id);
    expect((await b.load()).single.id, book.id);
    expect(await BookLibrary('C', root: root).load(), isEmpty);

    // Each child has their own progress.
    await a.markOpened(book, chapter: 3, total: 10);
    expect((await a.load()).single.chapter, 3);
    expect((await b.load()).single.chapter, 0);

    // Renamed for everyone.
    await shelf.rename(book.id, title: ' Alice Again ', author: ' L. C. ');
    expect((await b.load()).single.title, 'Alice Again');
    expect((await a.load()).single.author, 'L. C.');
    expect(() => shelf.rename(book.id, title: ' '), throwsFormatException);

    // Taken from A, who keeps their place in case it comes back.
    await shelf.setReaders(book.id, ['B']);
    expect(await a.load(), isEmpty);
    await shelf.setReaders(book.id, ['A', 'B']);
    expect((await a.load()).single.chapter, 3);

    // A child removing it only takes it off their own shelf.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(a.positionKey(book), 4);
    await prefs.setInt(b.positionKey(book), 9);
    await a.remove(book);
    expect(await a.load(), isEmpty);
    expect(prefs.getInt(a.positionKey(book)), isNull);
    expect((await b.load()).single.id, book.id);
    expect(File(book.filePath).existsSync(), isTrue);

    // Removing it from the shelf clears it for every child.
    await shelf.setReaders(book.id, ['A', 'B']);
    await a.markOpened(book, chapter: 2, total: 10);
    await prefs.setString(a.quizKey(book, 2), 'quiz');
    await shelf.remove(book);
    expect(await shelf.load(), isEmpty);
    expect(File(book.filePath).existsSync(), isFalse);
    expect(prefs.getInt(b.positionKey(book)), isNull);
    expect(prefs.getString(a.quizKey(book, 2)), isNull);
    expect(jsonDecode(prefs.getString('book_progress_A')!), isEmpty);
  });

  test('each child\'s old shelf moves onto the family shelf', () async {
    final root = tempRoot();
    File file(String name, List<int> bytes) =>
        File('${root.path}/$name')..writeAsBytesSync(bytes);
    final aliceA = file('a-alice.epub', alice.readAsBytesSync());
    final aliceB = file('b-alice.epub', alice.readAsBytesSync());
    final picA = file('a-pic.epub', [1, 2, 3]);
    final picB = file('b-pic.epub', [1, 2, 4]);
    Map<String, dynamic> legacy(
      String id,
      File file, {
      int chapter = 0,
      int? opened,
    }) => Book(
      id: id,
      title: id,
      author: '',
      filePath: file.path,
      chapter: chapter,
      chaptersTotal: chapter == 0 ? 0 : 12,
      addedAt: 1,
      lastOpenedAt: opened,
    ).toJson()..remove('readers');
    SharedPreferences.setMockInitialValues({
      'book_library_A': jsonEncode([
        legacy('alice.epub', aliceA, chapter: 3, opened: 50),
        legacy('pic.epub', picA),
      ]),
      'book_library_B': jsonEncode([
        legacy('alice.epub', aliceB, chapter: 1, opened: 60),
        legacy('pic.epub', picB),
      ]),
      'epub_position_B_alice.epub': 5,
      'epub_position_B_pic.epub': 7,
      'epub_cfi_B_pic.epub': 'epubcfi(/6/4)',
      'chapter_quiz_B_pic.epub_2': 'quiz',
    });

    final books = await BookShelf(root: root).load();
    expect(
      {for (final b in books) b.id: b.readers},
      {
        // The same book given to both is now one book.
        'alice.epub': ['A', 'B'],
        'pic.epub': ['A'],
        // A different book under the same name gets its own id.
        'pic-2.epub': ['B'],
      },
    );
    expect(aliceB.existsSync(), isFalse);
    expect(aliceA.existsSync(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('book_library_')),
      isEmpty,
    );
    final a = await BookLibrary('A', root: root).load();
    final b = await BookLibrary('B', root: root).load();
    expect(a.first.chapter, 3);
    expect(a.first.lastOpenedAt, 50);
    expect(b.first.chapter, 1);
    expect(b.first.lastOpenedAt, 60);
    // B's place in their "pic" followed it to its new id.
    final pic = b.last;
    final library = BookLibrary('B', root: root);
    expect(pic.id, 'pic-2.epub');
    expect(prefs.getInt(library.positionKey(pic)), 7);
    expect(prefs.getString(library.cfiKey(pic)), 'epubcfi(/6/4)');
    expect(prefs.getString(library.quizKey(pic, 2)), 'quiz');
    expect(prefs.getInt('epub_position_B_pic.epub'), isNull);
    expect(prefs.getInt(library.positionKey(b.first)), 5);

    // Already moved: loading again changes nothing.
    final again = await BookShelf(root: root).load();
    expect(again.map((b) => b.toJson()), books.map((b) => b.toJson()));
  });

  test('picture books are told apart, at import or once later', () async {
    SharedPreferences.setMockInitialValues({});
    final root = tempRoot();
    final shelf = BookShelf(root: root);
    Future<Book> add(String fixture) => shelf.add(
      fileName: fixture.split('/').last,
      bytes: File(fixture).readAsBytesSync(),
      title: fixture,
    );
    final pictures = await add('test/fixtures/picture_book.epub');
    final text = await add('test/fixtures/illustrated.epub');
    expect(pictures.pictureBook, isTrue);
    expect(text.pictureBook, isFalse);

    // A book from before this was recorded is looked at once.
    final old = Book.fromJson({...pictures.toJson(), 'pictureBook': null});
    expect(await shelf.isPictureBook(old), isTrue);
    expect(await shelf.isPictureBook(text), isFalse);
  });

  test('the lighter copy is made once even when asked for twice', () async {
    final root = tempRoot();
    final book = Book(
      id: 'pictures.epub',
      title: 'Pictures',
      author: '',
      filePath: File(
        'test/fixtures/illustrated.epub',
      ).copySync('${root.path}/pictures.epub').path,
      addedAt: 0,
    );
    final paths = await Future.wait([
      BookLibrary.lighterCopy(book, maxBytes: 1 << 20),
      BookLibrary.lighterCopy(book, maxBytes: 1 << 20),
    ]);
    expect(paths, [
      BookLibrary.lighterPath(book),
      BookLibrary.lighterPath(book),
    ]);
    expect(File('${BookLibrary.lighterPath(book)}.part').existsSync(), isFalse);
  });

  testWidgets('Manage Shelf infers the title, then renames and shares books', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final alex = testLibrary(child: 'alex');
    final sam = BookLibrary('sam', root: alex.root);
    final store = signedIn().store;
    await tester.runAsync(
      () => store.save([
        ChildProfile.withPin(id: 'alex', name: 'Alex', pin: '1111'),
        ChildProfile.withPin(id: 'sam', name: 'Sam', pin: '2222'),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookShelfScreen(shelf: alex.shelf, store: store),
      ),
    );
    await readingWork(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    final sample = find.text("Try sample: Alice's Adventures in Wonderland");
    await readingWork(
      tester,
      () => find.byType(TextFormField).evaluate().length == 2,
      action: () => tester.tap(sample),
    );
    // The title and author the book gives itself, for everyone at first.
    expect(
      find.widgetWithText(TextFormField, "Alice's Adventures in Wonderland"),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Lewis Carroll'), findsOneWidget);
    FilterChip chip(String name) =>
        tester.widget(find.widgetWithText(FilterChip, name));
    expect(chip('Alex').selected, isTrue);
    expect(chip('Sam').selected, isTrue);
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Sam'));
    await tester.tap(find.widgetWithText(FilterChip, 'Sam'));
    await tester.pump();
    expect(chip('Sam').selected, isFalse);

    await tester.ensureVisible(find.text('Add to shelf'));
    await readingWork(
      tester,
      () => find.text('Book added to your shelf.').evaluate().isNotEmpty,
      action: () => tester.tap(find.text('Add to shelf')),
    );
    expect(find.text('For Alex'), findsOneWidget);
    expect(await tester.runAsync(sam.load), isEmpty);

    // Rename.
    await tester.tap(find.byTooltip("Rename Alice's Adventures in Wonderland"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Book title'),
      'Alice',
    );
    await readingWork(
      tester,
      () => find.text('Alice').evaluate().isNotEmpty,
      action: () => tester.tap(find.text('Save')),
    );
    expect(find.text('Lewis Carroll'), findsOneWidget);

    // Give it to Sam too.
    await tester.tap(find.byTooltip('Choose who reads Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sam'));
    await tester.pump();
    await readingWork(
      tester,
      () => find.text('For Alex, Sam').evaluate().isNotEmpty,
      action: () => tester.tap(find.text('Save')),
    );
    final samBooks = await tester.runAsync(sam.load);
    expect(samBooks!.single.title, 'Alice');
    expect(tester.takeException(), isNull);
  });
}
