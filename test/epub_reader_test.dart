import 'dart:io';

// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/reading_module_page.dart';
import 'package:storysprout/services/activity_service.dart';

import 'test_helpers.dart';

void main() {
  setUp(() => ActivityService.instance = signedIn().activity);

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
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingModulePage(childId: '1', childName: 'Alex'),
      ),
    );
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
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingModulePage(childId: '1', childName: 'Alex'),
      ),
    );
    await tester.pumpAndSettle();
    // ZIP/XML decoding and image codecs need the real async event loop.
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose File'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        final views = tester.widgetList<EpubView>(find.byType(EpubView));
        if (views.isNotEmpty &&
            views.single.controller.loadingState.value !=
                EpubViewLoadingState.loading) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump(const Duration(seconds: 2));
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
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingModulePage(childId: '1', childName: 'Alex'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose File'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump();
        final views = tester.widgetList<EpubView>(find.byType(EpubView));
        if (views.isNotEmpty && views.single.controller.isBookLoaded.value) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump(const Duration(seconds: 2));

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
}
