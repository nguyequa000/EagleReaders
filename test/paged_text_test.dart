// The paged text reader itself is an epub.js web view, which only runs on a
// device (see PagedTextView). These tests cover the Dart side that decides
// which chapter a page is in, and that widget tests keep the scroll reader.
import 'dart:io';

import 'package:epub_view/epub_view.dart' show EpubDocument;
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart' as paged;
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/paged_text_view.dart';

void main() {
  test(
    'is not used off Android/iOS, so widget tests get the scroll reader',
    () {
      expect(pagedTextSupported, isFalse);
    },
  );

  group('spineIndexOfCfi', () {
    test('reads the spine step of a CFI', () {
      expect(spineIndexOfCfi('epubcfi(/6/2!/4/2/1:0)'), 0);
      expect(spineIndexOfCfi('epubcfi(/6/8!/4/2/1:0)'), 3);
      expect(spineIndexOfCfi('epubcfi(/6/14[chapter-5]!/4/10/1:120)'), 6);
    });

    test('is null for anything else', () {
      expect(spineIndexOfCfi(''), isNull);
      expect(spineIndexOfCfi('Text/chapter1.xhtml'), isNull);
    });
  });

  test('spineHrefs lists the reading order', () async {
    final book = await EpubDocument.openData(
      File('test/fixtures/picture_book.epub').readAsBytesSync(),
    );

    expect(spineHrefs(book), [
      'Text/cover.xhtml',
      'Text/page2.xhtml',
      'Text/page3.xhtml',
      'Text/page4.xhtml',
    ]);
  });

  group('chapters', () {
    const spine = [
      'OEBPS/Text/cover.xhtml',
      'OEBPS/Text/ch1.xhtml',
      'OEBPS/Text/ch1b.xhtml',
      'OEBPS/Text/ch2.xhtml',
    ];
    paged.EpubChapter entry(
      String title,
      String href, [
      List<paged.EpubChapter> subitems = const [],
    ]) => paged.EpubChapter(
      title: title,
      href: href,
      id: title,
      subitems: subitems,
    );
    final toc = [
      entry('Cover', 'Text/cover.xhtml'),
      entry('Chapter 1', 'Text/ch1.xhtml', [
        entry('A scene', 'Text/ch1.xhtml#scene'),
      ]),
      entry('Chapter 2', 'OEBPS/Text/ch2.xhtml'),
      entry('Missing', 'Text/nowhere.xhtml'),
    ];

    test('match contents entries to the spine, keeping nesting', () {
      expect(
        [
          for (final c in pagedChapters(toc, spine))
            (c.title, c.spineIndex, c.depth),
        ],
        [
          ('Cover', 0, 0),
          ('Chapter 1', 1, 0),
          ('A scene', 1, 1),
          ('Chapter 2', 3, 0),
          ('Missing', null, 0),
        ],
      );
    });

    test('pagedChapterAt finds the chapter a page belongs to', () {
      final chapters = pagedChapters(toc, spine);
      expect(
        [for (var i = 0; i < 4; i++) pagedChapterAt(chapters, i)?.title],
        // ch1b.xhtml has no entry of its own, so it is still in Chapter 1;
        // two entries at the same spot resolve to the later, deeper one.
        ['Cover', 'A scene', 'A scene', 'Chapter 2'],
      );
    });
  });
}
