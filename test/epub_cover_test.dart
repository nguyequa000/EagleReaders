import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/epub_cover.dart';

import 'reading_test_helpers.dart';

const _alice = 'assets/books/alice_in_wonderland.epub';

bool _isJpeg(List<int> bytes) =>
    bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('coverHref', () {
    test('EPUB 3: the cover-image item', () {
      expect(
        coverHref('''
<manifest>
  <item href="pic.jpg" id="a" media-type="image/jpeg"/>
  <item properties="cover-image" href="images/front.png" id="b" media-type="image/png"/>
</manifest>'''),
        'images/front.png',
      );
    });

    test('EPUB 2: the item <meta name="cover"> names', () {
      expect(
        coverHref(
          '''
<metadata><meta content="CoverId" name="cover"/></metadata>
<manifest><item id="coverid" href="c.jpg" media-type="image/jpeg"/></manifest>''',
        ),
        'c.jpg',
      );
    });

    test('otherwise an image called cover', () {
      expect(
        coverHref(
          '<item id="x1" href="Images/Cover-art.jpeg" media-type="image/jpeg"/>',
        ),
        'Images/Cover-art.jpeg',
      );
    });

    test('a cover page (XHTML) is not a cover image', () {
      expect(
        coverHref(
          '<item id="cover" href="cover.xhtml" '
          'media-type="application/xhtml+xml"/>',
        ),
        isNull,
      );
    });
  });

  test("the Alice sample's EPUB 3 cover is found", () {
    final cover = readEpubCover(_alice)!;
    expect(cover.extension, 'jpg');
    expect(_isJpeg(cover.bytes), isTrue);
    expect(cover.bytes.length, greaterThan(10000));
  });

  test('a file that is not an EPUB has no cover', () {
    final dir = Directory.systemTemp.createTempSync('cover-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bogus = File('${dir.path}/bogus.epub')..writeAsStringSync('nope');
    expect(readEpubCover(bogus.path), isNull);
  });

  test('adding Alice to a shelf now keeps its cover', () async {
    final library = testLibrary(child: 'kid-1');
    final book = await library.add(
      fileName: 'alice_in_wonderland.epub',
      bytes: File(_alice).readAsBytesSync(),
      title: "Alice's Adventures in Wonderland",
    );
    expect(book.coverPath, isNotNull);
    expect(_isJpeg(File(book.coverPath!).readAsBytesSync()), isTrue);

    await library.remove(book);
    expect(File(book.coverPath!).existsSync(), isFalse);
  });

  test('a book saved without its cover gets it back, once', () async {
    final library = testLibrary(child: 'kid-1');
    final epub = File('${library.root!.path}/alice.epub')
      ..writeAsBytesSync(File(_alice).readAsBytesSync());
    // The shelf as it was before EPUB 3 covers were read.
    final stored = Book(
      id: 'alice.epub',
      title: 'Alice',
      author: '',
      filePath: epub.path,
      addedAt: 1,
    );
    SharedPreferences.setMockInitialValues({
      'book_library_kid-1': jsonEncode([stored.toJson()]),
    });

    final filled = await library.fillMissingCovers();
    final cover = filled.single.coverPath;
    expect(cover, isNotNull);
    expect(_isJpeg(File(cover!).readAsBytesSync()), isTrue);
    expect((await library.load()).single.coverPath, cover);

    // A book with no cover at all is only looked at once.
    final none = File('${library.root!.path}/none.epub')
      ..writeAsStringSync('not a zip');
    SharedPreferences.setMockInitialValues({
      'book_library_kid-1': jsonEncode([
        Book(
          id: 'none.epub',
          title: 'None',
          author: '',
          filePath: none.path,
          addedAt: 2,
        ).toJson(),
      ]),
    });
    expect((await library.fillMissingCovers()).single.coverPath, isNull);
    none.deleteSync();
    // Gone now, but it was marked as checked, so this doesn't look again.
    expect((await library.fillMissingCovers()).single.coverPath, isNull);
  });
}
