import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/reading_library_screen.dart';
import 'package:storysprout/services/book_library.dart';

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
        childName: library.childName,
        library: library,
      ),
    ),
  );
  await readingWork(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

Future<void> importBook(
  WidgetTester tester,
  String title, {
  String? author,
}) async {
  await tester.tap(find.text('Add Book'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose File'));
  await tester.pumpAndSettle();
  expect(find.byType(TextFormField), findsNWidgets(2));
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
  await tester.pumpAndSettle();
}

Future<void> openShelfBook(WidgetTester tester, String title) async {
  await readingWork(tester, () {
    final views = tester.widgetList<EpubView>(find.byType(EpubView));
    return views.isNotEmpty && views.single.controller.isBookLoaded.value;
  }, action: () => tester.tap(find.text(title)));
}
