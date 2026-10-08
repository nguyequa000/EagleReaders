// Big illustrated EPUBs (Treasure Island with images is 49 MB, nearly all
// JPEGs) were over the paged reader's size limit and fell back to scrolling.
// The reader now reads a copy with the pictures re-saved smaller.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/lighter_epub.dart';

/// A big, noisy picture saved at full quality, like the ones in Gutenberg's
/// illustrated editions.
List<int> _bigJpeg() {
  final rng = Random(1);
  final picture = image.Image(1800, 1200);
  for (var y = 0; y < picture.height; y++) {
    for (var x = 0; x < picture.width; x++) {
      picture.setPixelRgba(x, y, rng.nextInt(256), x % 256, y % 256);
    }
  }
  return image.encodeJpg(picture, quality: 100);
}

Uint8List _epub(List<int> picture) {
  final archive = Archive()
    ..addFile(ArchiveFile('mimetype', 20, 'application/epub+zip'.codeUnits)
      ..compress = false)
    ..addFile(ArchiveFile('OEBPS/text.xhtml', 11, 'hello world'.codeUnits))
    ..addFile(ArchiveFile('OEBPS/picture.jpg', picture.length, picture));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('re-saves big pictures smaller and keeps the rest of the book', () {
    final dir = Directory.systemTemp.createTempSync('lighter-epub-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/book.epub')
      ..writeAsBytesSync(_epub(_bigJpeg()));

    shrinkEpubFile(original.path, '${dir.path}/lighter.epub');

    final lighter = File('${dir.path}/lighter.epub').readAsBytesSync();
    expect(lighter.length, lessThan(original.lengthSync() ~/ 2));
    final files = ZipDecoder().decodeBytes(lighter).files;
    expect(files.map((f) => f.name), [
      'mimetype',
      'OEBPS/text.xhtml',
      'OEBPS/picture.jpg',
    ]);
    // The EPUB spec wants the mimetype first and stored, not deflated.
    expect(files.first.compress, isFalse);
    expect(String.fromCharCodes(files.first.content as List<int>),
        'application/epub+zip');
    expect(String.fromCharCodes(files[1].content as List<int>), 'hello world');
    final resized = image.decodeJpg(files[2].content as List<int>)!;
    expect(resized.width, 800);
    expect(resized.height, 533);
  });

  test('the lighter copy is made once, reused and removed with the book',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final root = Directory.systemTemp.createTempSync('lighter-epub-test-');
    addTearDown(() => root.deleteSync(recursive: true));
    final library = BookLibrary('1', root: root);
    final bytes = File('test/fixtures/illustrated.epub').readAsBytesSync();
    final book = await library.add(
      fileName: 'illustrated.epub',
      bytes: bytes,
      title: 'Illustrated',
    );

    final path = await BookLibrary.lighterCopy(book, maxBytes: 1024 * 1024);
    expect(path, BookLibrary.lighterPath(book));
    expect(File(path!).existsSync(), isTrue);

    // Reused: a second call doesn't redo the work.
    final made = File(path).lastModifiedSync();
    expect(await BookLibrary.lighterCopy(book, maxBytes: 1024 * 1024), path);
    expect(File(path).lastModifiedSync(), made);

    // Still too big for the reader: say so rather than hand it over.
    expect(await BookLibrary.lighterCopy(book, maxBytes: 10), isNull);

    await library.remove(book);
    expect(File(path).existsSync(), isFalse);
  });
}
