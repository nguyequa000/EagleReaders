import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/book_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Shelf persists books, serializes updates, validates and removes files',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = Directory.systemTemp.createTempSync('book-library-test-');
      addTearDown(() => root.deleteSync(recursive: true));
      final library = BookLibrary('Alex/../test', root: root);
      final bytes = File('test/fixtures/illustrated.epub').readAsBytesSync();
      final book = await library.add(
        fileName: 'illustrated.epub',
        bytes: bytes,
        title: ' My own title ',
        author: ' A Writer ',
      );
      expect(book.title, 'My own title');
      expect(book.author, 'A Writer');
      expect(File(book.filePath).readAsBytesSync(), bytes);
      final duplicate = await library.add(
        fileName: 'illustrated.epub',
        bytes: bytes,
        title: 'Another book',
      );
      expect(duplicate.id, 'illustrated-2.epub');
      expect(duplicate.filePath, isNot(book.filePath));
      await Future.wait([
        library.markOpened(book, chapter: 1, total: 4),
        library.markOpened(duplicate, chapter: 2, total: 3),
      ]);
      final restored = await BookLibrary(library.childName, root: root).load();
      expect(restored.map((b) => b.chapter), [1, 2]);
      expect(restored.first.lastOpenedAt, isNotNull);
      expect(await BookLibrary('Sam', root: root).load(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(library.positionKey(book), 10);
      await library.remove(book);
      expect(File(book.filePath).existsSync(), isFalse);
      expect(prefs.getInt(library.positionKey(book)), isNull);
      expect((await library.load()).single.id, duplicate.id);
      expect(File(duplicate.filePath).existsSync(), isTrue);
      for (final name in ['book.txt', 'book.epub']) {
        await expectLater(
          library.add(
            fileName: name,
            bytes: Uint8List.fromList([1, 2]),
            title: 'Broken',
          ),
          throwsA(anything),
        );
      }
      await expectLater(
        library.add(
          fileName: 'empty.epub',
          bytes: Uint8List(0),
          title: 'Empty',
        ),
        throwsFormatException,
      );
      await expectLater(
        library.add(fileName: 'valid.epub', bytes: bytes, title: '  '),
        throwsFormatException,
      );
      expect((await library.load()).length, 1);
    },
  );
}
