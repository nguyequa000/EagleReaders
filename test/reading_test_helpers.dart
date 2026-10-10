import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/book_shelf_screen.dart';
import 'package:storysprout/screens/reading_library_screen.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/child_profiles.dart';

import 'test_helpers.dart';

BookLibrary testLibrary({String child = 'Alex', Directory? root}) {
  final directory =
      root ?? Directory.systemTemp.createTempSync('reading-test-');
  if (root == null) addTearDown(() => directory.deleteSync(recursive: true));
  return BookLibrary(child, root: directory);
}

// ZIP/XML decoding, filesystem IO and image codecs need the real event loop.
Future<void> readingWork(
  WidgetTester tester,
  bool Function() done, {
  Future<void> Function()? action,
}) async {
  await tester.runAsync(() async {
    await action?.call();
    for (var attempt = 0; attempt < 250; attempt++) {
      await tester.pump();
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  expect(done(), isTrue, reason: 'Reading operation did not complete');
  await tester.pumpAndSettle();
}

Future<void> showLibrary(WidgetTester tester, BookLibrary library) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    MaterialApp(
      home: ReadingLibraryScreen(
        // The test child's id doubles as their name.
        childId: library.childId,
        childName: library.childId,
        library: library,
      ),
    ),
  );
  await readingWork(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

/// An account whose only child is [library]'s, named by their id.
Future<ChildProfileStore> testStore(
  WidgetTester tester,
  BookLibrary library,
) async {
  final store = signedIn().store;
  await tester.runAsync(
    () => store.save([
      ChildProfile.withPin(
        id: library.childId,
        name: library.childId,
        pin: '1234',
      ),
    ]),
  );
  return store;
}

/// Manage Shelf, on [library]'s storage, with its child on the account.
Future<void> showShelf(WidgetTester tester, BookLibrary library) async {
  final store = await testStore(tester, library);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    MaterialApp(
      home: BookShelfScreen(shelf: library.shelf, store: store),
    ),
  );
  await readingWork(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

/// Adds a book as the parent, for [library]'s child, then reopens the shelf
/// as the child.
Future<void> importBook(
  WidgetTester tester,
  BookLibrary library,
  String title, {
  String? author,
}) async {
  await showShelf(tester, library);
  await tester.tap(find.text('Import'));
  await tester.pumpAndSettle();
  await readingWork(
    tester,
    () => find.byType(TextFormField).evaluate().length == 2,
    action: () => tester.tap(find.text('Choose File')),
  );
  await tester.enterText(find.byType(TextFormField).first, title);
  if (author != null) {
    await tester.enterText(find.byType(TextFormField).last, author);
  }
  await tester.ensureVisible(find.text('Add to shelf'));
  await readingWork(
    tester,
    () => find.text('Book added to your shelf.').evaluate().isNotEmpty,
    action: () => tester.tap(find.text('Add to shelf')),
  );
  await showLibrary(tester, library);
}

Future<void> openShelfBook(WidgetTester tester, String title) async {
  await readingWork(tester, () {
    final views = tester.widgetList<EpubView>(find.byType(EpubView));
    return views.isNotEmpty && views.single.controller.isBookLoaded.value;
  }, action: () => tester.tap(find.text(title)));
}
