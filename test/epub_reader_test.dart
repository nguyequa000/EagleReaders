import 'dart:io';

// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/screens/reading_library_screen.dart';
import 'package:storysprout/screens/reading_module_page.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/story_generator.dart';

import 'reading_test_helpers.dart';
import 'test_helpers.dart';

void main() {
  setUp(() => ActivityService.instance = signedIn().activity);

  testWidgets(
    'Batch failure keeps successful imports and retries without duplicates',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      MethodChannelFilePicker.registerWith();
      final bytes = File('test/fixtures/illustrated.epub').readAsBytesSync();
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {
            'name': 'first.epub',
            'size': bytes.length,
            'bytes': bytes,
            'path': null,
          },
          {
            'name': 'broken.epub',
            'size': 2,
            'bytes': Uint8List.fromList([1, 2]),
            'path': null,
          },
          {
            'name': 'last.epub',
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
      final library = testLibrary();
      await showLibrary(tester, library, canManage: true);
      await tester.tap(find.text('Add Book'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(6));
      await tester.ensureVisible(find.text('Add to shelf'));
      await readingWork(
        tester,
        () => find
            .text('Could not open this EPUB. It may be damaged or unsupported.')
            .evaluate()
            .isNotEmpty,
        action: () => tester.tap(find.text('Add to shelf')),
      );
      final saved = await tester.runAsync(library.load);
      expect(saved!.map((b) => b.id), ['first.epub']);
      expect(find.byType(TextFormField), findsNWidgets(4));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Discard broken.epub'));
      await tester.tap(find.byTooltip('Discard broken.epub'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add to shelf'));
      await readingWork(
        tester,
        () => find.text('Book added to your shelf.').evaluate().isNotEmpty,
        action: () => tester.tap(find.text('Add to shelf')),
      );
      final retried = await tester.runAsync(library.load);
      expect(retried!.map((b) => b.id), ['first.epub', 'last.epub']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sample import, title validation and deletion work on a small screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = testLibrary();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ReadingLibraryScreen(
            childId: 'Alex',
            childName: 'Alex',
            library: library,
            canManage: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Book'));
      await tester.pumpAndSettle();
      final sample = find.text("Try sample: Alice's Adventures in Wonderland");
      await tester.ensureVisible(sample);
      await readingWork(
        tester,
        () => find.byType(TextFormField).evaluate().length == 2,
        action: () => tester.tap(sample),
      );
      await tester.enterText(find.byType(TextFormField).first, '  ');
      await tester.ensureVisible(find.text('Add to shelf'));
      await tester.tap(find.text('Add to shelf'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a book title.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'My sample adventure',
      );
      await tester.ensureVisible(find.text('Add to shelf'));
      await readingWork(
        tester,
        () => find.text('Book added to your shelf.').evaluate().isNotEmpty,
        action: () => tester.tap(find.text('Add to shelf')),
      );
      expect(find.text('My sample adventure'), findsOneWidget);
      expect(find.text('Lewis Carroll'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Remove My sample adventure'));
      await tester.pumpAndSettle();
      await readingWork(
        tester,
        () =>
            find.text('Your next adventure starts here').evaluate().isNotEmpty,
        action: () => tester.tap(find.text('Remove')),
      );
      expect(await tester.runAsync(library.load), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Reader is EPUB-only and rejects text imports', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MethodChannelFilePicker.registerWith();
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    MethodCall? request;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      request = call;
      return [
        {
          'name': 'book.txt',
          'size': 4,
          'bytes': Uint8List.fromList([116, 101, 120, 116]),
          'path': null,
        },
      ];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await showLibrary(tester, testLibrary(), canManage: true);
    await tester.tap(find.text('Add Book'));
    await tester.pumpAndSettle();
    expect(find.textContaining('.txt'), findsNothing);
    await tester.tap(find.text('Choose File'));
    await tester.pumpAndSettle();
    expect(request!.arguments['allowedExtensions'], ['epub']);
    expect(find.text('Please choose an .epub file.'), findsOneWidget);
    expect(find.byType(EpubView), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Opens a real EPUB from bytes without a filesystem path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    MethodChannelFilePicker.registerWith();
    final bytes = File(
      'assets/books/alice_in_wonderland.epub',
    ).readAsBytesSync();
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'name': 'alice.epub',
          'size': bytes.length,
          'bytes': bytes,
          'path': null,
        },
      ],
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    final library = testLibrary();
    await importBook(tester, library, 'My Alice book', author: 'Lewis Carroll');
    expect(find.text('Lewis Carroll'), findsOneWidget);
    await openShelfBook(tester, 'My Alice book');
    expect(find.byTooltip('Import EPUB'), findsNothing);
    expect(find.byType(EpubView), findsOneWidget);
    final view = tester.widget<EpubView>(find.byType(EpubView));
    expect(view.controller.isBookLoaded.value, isTrue);
    final toc = view.controller.tableOfContents();
    expect(toc, isNotEmpty);
    for (var i = 1; i < toc.length; i++) {
      expect(toc[i].startIndex, greaterThan(toc[i - 1].startIndex));
    }
    expect(view.controller.currentValue?.chapterNumber, 1);
    final options = view.builders.options as DefaultBuilderOptions;
    expect(options.textStyle.fontSize, 20);
    expect(options.textStyle.height, 1.6);
    expect(find.byTooltip('Contents'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.bySemanticsLabel('Reading progress'), findsOneWidget);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reading out of a chapter brings up a quiz Gemini wrote from it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    MethodChannelFilePicker.registerWith();
    final bytes = File(
      'assets/books/alice_in_wonderland.epub',
    ).readAsBytesSync();
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {'name': 'alice.epub', 'size': bytes.length, 'bytes': bytes},
      ],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final asked = <(String, String)>[];
    ReadingModulePage.writeChapterQuiz = (book, chapter, html) async {
      asked.add((chapter, bookExcerpt(html)));
      return const [
        ComprehensionQuestion(
          question: 'What did Alice follow?',
          answers: ['A White Rabbit', 'A cat', 'A dog'],
          correctIndex: 0,
        ),
      ];
    };
    addTearDown(
      () => ReadingModulePage.writeChapterQuiz = generateChapterQuestions,
    );
    await importBook(tester, testLibrary(), 'My Alice book');
    await openShelfBook(tester, 'My Alice book');

    final controller = tester.widget<EpubView>(find.byType(EpubView)).controller;
    final toc = controller.tableOfContents();
    final one = toc.indexWhere((c) => c.title!.startsWith('CHAPTER I.'));
    // Read into Chapter I, then on into Chapter II.
    for (final chapter in [one, one + 1]) {
      controller.jumpTo(index: toc[chapter].startIndex);
      await tester.pumpAndSettle();
    }

    expect(find.byType(ComprehensionScreen), findsOneWidget);
    expect(find.text('What did Alice follow?'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    final (title, text) = asked.single;
    expect(title, startsWith('CHAPTER I.'));
    // Chapter I's own text, not the next chapter's.
    expect(text, contains('White Rabbit'));
    expect(text, isNot(contains('Pool of Tears')));

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(EpubView), findsOneWidget);
  });

  testWidgets('Renders EPUB markup and embedded images, not flattened text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    MethodChannelFilePicker.registerWith();
    // A small hand-built EPUB with bold/italic markup, accented characters and
    // an embedded PNG (see test/fixtures/illustrated.epub).
    final bytes = File('test/fixtures/illustrated.epub').readAsBytesSync();
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'name': 'illustrated.epub',
          'size': bytes.length,
          'bytes': bytes,
          'path': null,
        },
      ],
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await importBook(tester, testLibrary(), 'illustrated.epub');
    await openShelfBook(tester, 'illustrated.epub');

    // Inline markup and non-ASCII characters survive into the rendered spans.
    expect(find.textContaining('bold words', findRichText: true), findsWidgets);
    expect(
      find.textContaining('italic words', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('café', findRichText: true), findsWidgets);
    expect(find.textContaining('Việt Nam', findRichText: true), findsWidgets);
    final spans = tester
        .widgetList<RichText>(find.byType(RichText))
        .expand((rich) => [rich.text.toPlainText()])
        .join(' ');
    expect(spans, isNot(contains('<strong>')));
    expect(spans, isNot(contains('&#')));

    // The image packaged inside the EPUB is decoded from archive bytes.
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images, isNotEmpty);
    expect(images.first.image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Children read their shelf but cannot add or remove books', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final library = testLibrary();
    await showLibrary(tester, library);
    expect(find.text('Add Book'), findsNothing);
    expect(
      find.text('Ask a grown-up to add books to your shelf.'),
      findsOneWidget,
    );
    expect(find.textContaining('Add the first book'), findsNothing);

    await tester.runAsync(
      () => library.add(
        fileName: 'alice.epub',
        bytes: File('assets/books/alice_in_wonderland.epub').readAsBytesSync(),
        title: 'Alice',
      ),
    );
    await showLibrary(tester, library);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byTooltip('Remove Alice'), findsNothing);

    await showLibrary(tester, library, canManage: true);
    expect(find.text('Add Book'), findsOneWidget);
    expect(find.byTooltip('Remove Alice'), findsOneWidget);
  });
}
