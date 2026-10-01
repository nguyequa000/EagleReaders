// Regression tests for the large-EPUB crash: a 96 MB image-heavy EPUB killed
// the app on Android with an OutOfMemoryError because the file picker was
// asked to send the whole file over the platform channel (`withData: true`).
// Off web the reader now asks only for a path and reads the file in Dart.
import 'dart:io';

import 'package:epub_view/epub_view.dart';
// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/reading_module_page.dart';
import 'package:storysprout/services/activity_service.dart';

import 'test_helpers.dart';

void main() {
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActivityService.instance = signedIn().activity;
    MethodChannelFilePicker.registerWith();
  });

  /// Makes the picker return [file] and records the call it received.
  List<MethodCall> mockPicker(WidgetTester tester, Map<String, Object?> file) {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return [file];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    return calls;
  }

  Future<void> chooseFile(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingModulePage(childId: '1', childName: 'Alex'),
      ),
    );
    await tester.pumpAndSettle();
    // File and ZIP decoding need the real async event loop.
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
    await tester.pumpAndSettle();
  }

  testWidgets('Opens an EPUB from its path without asking for the bytes', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('epub_import');
    addTearDown(() => dir.deleteSync(recursive: true));
    final book = File(
      'assets/books/alice_in_wonderland.epub',
    ).copySync('${dir.path}/alice.epub');

    final calls = mockPicker(tester, {
      'name': 'alice.epub',
      'size': book.lengthSync(),
      'bytes': null,
      'path': book.path,
    });
    await chooseFile(tester);

    expect(calls.single.arguments['withData'], isFalse);
    expect(find.byType(EpubView), findsOneWidget);
    expect(
      tester
          .widget<EpubView>(find.byType(EpubView))
          .controller
          .isBookLoaded
          .value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Refuses a file over the size limit without reading it', (
    tester,
  ) async {
    mockPicker(tester, {
      'name': 'huge.epub',
      'size': 200 * 1024 * 1024,
      'bytes': null,
      // Never read: the size check comes first, so a missing file is fine.
      'path': '/does/not/exist/huge.epub',
    });
    await chooseFile(tester);

    expect(find.text('This book is too large to open.'), findsOneWidget);
    expect(find.byType(EpubView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
