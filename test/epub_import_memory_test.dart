// Regression tests for the large-EPUB crash: a 96 MB image-heavy EPUB killed
// the app on Android with an OutOfMemoryError because the file picker was
// asked to send the whole file over the platform channel (`withData: true`).
// Off web the library now asks only for a path and reads the file in Dart.
import 'dart:io';

// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/activity_service.dart';

import 'reading_test_helpers.dart';
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

  /// Opens Manage Shelf's Import tab and picks a file; [done] says when the
  /// picker's result has been handled.
  Future<void> chooseFile(WidgetTester tester, bool Function() done) async {
    await showShelf(tester, testLibrary());
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    // File IO needs the real async event loop.
    await readingWork(
      tester,
      done,
      action: () => tester.tap(find.text('Choose File')),
    );
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
    await chooseFile(
      tester,
      () => find.byType(TextFormField).evaluate().length == 2,
    );

    expect(calls.single.arguments['withData'], isFalse);
    // The file was read from its path, ready to add to the shelf.
    expect(find.text('Add to shelf'), findsOneWidget);
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
    await chooseFile(
      tester,
      () => find.text('This book is too large to open.').evaluate().isNotEmpty,
    );

    expect(find.text('This book is too large to open.'), findsOneWidget);
    expect(find.text('Add to shelf'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
