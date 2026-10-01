// Picture books (comics, fixed-layout scans): every page is one image and
// there is no real text. They are shown one page at a time instead of as one
// long scroll. test/fixtures/picture_book.epub mirrors the structure of a real
// comic EPUB: a fixed-layout spine of four image-only pages (the cover drawn
// with an SVG <image>, the rest with <img>) and a contents file that covers
// Cover (p. 1), Chapter 1 (p. 2) with a nested Part A (p. 3, linked through
// an #anchor), and Chapter 2 (p. 4).
import 'dart:io';

import 'package:epub_view/epub_view.dart' hide Image;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/screens/picture_book_view.dart';
import 'package:storysprout/screens/reading_module_page.dart';
import 'package:storysprout/services/activity_service.dart';

import 'test_helpers.dart';

void main() {
  const fixture = 'test/fixtures/picture_book.epub';

  group('readPictureBook', () {
    test('returns every spine page image in reading order', () async {
      final book = await EpubDocument.openData(File(fixture).readAsBytesSync());

      final pictures = readPictureBook(book)!;

      final images = book.Content!.Images!;
      expect(pictures.pages, [
        for (var n = 1; n <= 4; n++) images['Images/page$n.png']!.Content,
      ]);
    });

    test('maps the contents, including nested entries, to pages', () async {
      final book = await EpubDocument.openData(File(fixture).readAsBytesSync());

      final chapters = readPictureBook(book)!.chapters;

      expect(
        [for (final c in chapters) (c.title, c.page, c.depth)],
        [
          ('Cover', 0, 0),
          ('Chapter 1', 1, 0),
          ('Part A', 2, 1),
          ('Chapter 2', 3, 0),
        ],
      );
    });

    test('chapterAt finds the chapter a page belongs to', () async {
      final book = await EpubDocument.openData(File(fixture).readAsBytesSync());
      final pictures = readPictureBook(book)!;

      expect(
        [for (var page = 0; page < 4; page++) pictures.chapterAt(page)?.title],
        ['Cover', 'Chapter 1', 'Part A', 'Chapter 2'],
      );
    });

    test('is null for a text book with illustrations', () async {
      for (final path in [
        'assets/books/alice_in_wonderland.epub',
        'test/fixtures/illustrated.epub',
      ]) {
        final book = await EpubDocument.openData(File(path).readAsBytesSync());
        expect(readPictureBook(book), isNull, reason: path);
      }
    });
  });

  group('reader', () {
    late FakeFirebaseFirestore firestore;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final ctx = signedIn();
      ActivityService.instance = ctx.activity;
      firestore = ctx.firestore;
      MethodChannelFilePicker.registerWith();
    });

    Future<void> openPictureBook(WidgetTester tester) async {
      final bytes = File(fixture).readAsBytesSync();
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {
            'name': 'picture.epub',
            'size': bytes.length,
            'bytes': bytes,
            'path': null,
          },
        ],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(
          home: ReadingModulePage(childId: '1', childName: 'Alex'),
        ),
      );
      await tester.pumpAndSettle();
      // ZIP decoding needs the real async event loop.
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose File'));
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.pump();
          if (find.byType(PictureBookView).evaluate().isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
    }

    testWidgets('shows one page at a time and turns exactly one page', (
      tester,
    ) async {
      await openPictureBook(tester);

      expect(find.byType(PictureBookView), findsOneWidget);
      expect(find.byType(EpubView), findsNothing);
      expect(find.text('Page 1 of 4'), findsOneWidget);
      expect(find.text('Cover · 3 pages left'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 4'), findsOneWidget);

      // A hard fling still turns only one page.
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 3000);
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 4'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // Leaving Chapter 1 brings up its quiz (covered below); skip it.
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Page 4 of 4'), findsOneWidget);
      expect(find.text('Chapter 2 · Last page!'), findsOneWidget);
      expect(find.text('Finish book'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('end-of-chapter quiz', () {
      Future<void> readToChapter2(WidgetTester tester) async {
        await openPictureBook(tester);
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }

      testWidgets('appears on turning the page out of a chapter', (
        tester,
      ) async {
        await openPictureBook(tester);
        // Cover -> Chapter 1 -> Part A (still Chapter 1): no quiz yet.
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(find.byType(ComprehensionScreen), findsNothing);
        }

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.byType(ComprehensionScreen), findsOneWidget);
        expect(find.text('Chapter 1'), findsOneWidget); // quiz header
        expect(find.text('Skip'), findsOneWidget);
      });

      testWidgets('Skip returns to the book without recording a score', (
        tester,
      ) async {
        await readToChapter2(tester);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.byType(ComprehensionScreen), findsNothing);
        expect(find.text('Page 4 of 4'), findsOneWidget);
        final events = await activityDocs(firestore, '1');
        expect(
          events.where((e) => e['type'] == 'comprehension_result'),
          isEmpty,
        );

        // Going back into Chapter 1 and out again doesn't ask again.
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.byType(ComprehensionScreen), findsNothing);
      });

      testWidgets('answering records the score against the chapter', (
        tester,
      ) async {
        await readToChapter2(tester);
        await tester.runAsync(() async {
          await tester.tap(find.text('Water and sunlight'));
          await tester.pump();
          await tester.tap(find.text('Next Question →'));
          await tester.pump();
          await tester.tap(find.text('In a garden'));
          await tester.pump();
          await tester.tap(find.text('Keep Reading →'));
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();

        expect(find.byType(ComprehensionScreen), findsNothing);
        expect(find.text('Page 4 of 4'), findsOneWidget);
        final result = (await activityDocs(
          firestore,
          '1',
        )).singleWhere((e) => e['type'] == 'comprehension_result');
        expect(result['chapterTitle'], 'Chapter 1');
        expect(result['chapter'], 1);
        expect(result['score'], '2/2');
      });

      testWidgets('jumping from Contents does not count as finishing', (
        tester,
      ) async {
        await openPictureBook(tester);
        await tester.tap(find.text('Next')); // into Chapter 1
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Contents'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Chapter 2'));
        await tester.pumpAndSettle();

        expect(find.text('Page 4 of 4'), findsOneWidget);
        expect(find.byType(ComprehensionScreen), findsNothing);
      });
    });

    testWidgets('a quick flick turns the page', (tester) async {
      // A real flick covers a lot of ground between touch events. The first
      // move already passes every gesture threshold, so the zoom handler must
      // not be in a position to claim it ahead of the page swipe.
      await openPictureBook(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      // Big jumps 8 ms apart: about 10,000 px/s.
      for (var i = 1; i <= 3; i++) {
        await gesture.moveBy(
          const Offset(-80, 0),
          timeStamp: Duration(milliseconds: 8 * i),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 32));
      await tester.pumpAndSettle();

      expect(find.text('Page 2 of 4'), findsOneWidget);
    });

    testWidgets('Contents lists the chapters and jumps to one', (tester) async {
      await openPictureBook(tester);

      await tester.tap(find.byTooltip('Contents'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      for (final (title, page) in [
        ('Cover', 'p. 1'),
        ('Chapter 1', 'p. 2'),
        ('Part A', 'p. 3'),
      ]) {
        expect(
          find.descendant(
            of: sheet,
            matching: find.widgetWithText(ListTile, title),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text(page)),
          findsOneWidget,
        );
      }
      // The chapter being read is highlighted.
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Cover'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ListTile, 'Part A'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Page 3 of 4'), findsOneWidget);
      expect(find.text('Part A · 1 page left'), findsOneWidget);
      // The reader's title bar names the chapter too.
      expect(find.text('picture.epub\nPart A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('double-tap zooms in, locks the page, and zooms back out', (
      tester,
    ) async {
      await openPictureBook(tester);
      Future<void> doubleTap() async {
        final center = tester.getCenter(find.byType(PageView));
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(center);
        await tester.pumpAndSettle();
      }

      await doubleTap();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // While zoomed, even a hard fling pans the page instead of turning it.
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 3000);
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 4'), findsOneWidget);

      await doubleTap();
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 3000);
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 4'), findsOneWidget);
    });

    testWidgets('records the book as opened and resumes at the saved page', (
      tester,
    ) async {
      await openPictureBook(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(prefs.getInt('epub_position_Alex_picture.epub'), 2);

      await openPictureBook(tester);
      expect(find.text('Page 3 of 4'), findsOneWidget);

      final events = await activityDocs(firestore, '1');
      expect(events.map((e) => e['type']), ['book_opened', 'book_opened']);
      expect(events.first['title'], 'picture.epub');
      expect(tester.takeException(), isNull);
    });
  });
}
