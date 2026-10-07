import 'dart:convert';
import 'dart:io';

import 'package:epub_view/epub_view.dart';
// file_picker has no public mock-registration API.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/reading_module_page.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/story_generator.dart';

import 'test_helpers.dart';
import 'reading_test_helpers.dart';

void main() {
  testWidgets('EPUB resumes, saves settings, and reports activity to parents', (
    tester,
  ) async {
    MethodChannelFilePicker.registerWith();
    SharedPreferences.setMockInitialValues({
      'font_size': 24.0,
      'line_height': 1.8,
      'reader_theme': 'paper',
    });
    final prefs = await SharedPreferences.getInstance();
    String? quizBook;
    var quizText = '';
    ReadingModulePage.generateQuestions = (title, chapterHtml) async {
      quizBook = title;
      quizText = bookExcerpt(chapterHtml);
      return const [
        ComprehensionQuestion(
          question: 'Who follows the White Rabbit?',
          answers: ['Alice', 'The Queen', 'The Hatter'],
          correctIndex: 0,
        ),
        ComprehensionQuestion(
          question: 'What does Alice fall down?',
          answers: ['A well', 'A rabbit-hole', 'A hill'],
          correctIndex: 1,
        ),
      ];
    };
    addTearDown(
      () => ReadingModulePage.generateQuestions = generateBookQuestions,
    );
    final library = testLibrary();
    var fileName = 'alice.epub';
    final bytes = File(
      'assets/books/alice_in_wonderland.epub',
    ).readAsBytesSync();
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {'name': fileName, 'size': bytes.length, 'bytes': bytes, 'path': null},
      ],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    EpubView view() => tester.widget<EpubView>(find.byType(EpubView));
    Future<void> openReader({String child = 'Alex'}) async {
      final shelf = child == 'Alex'
          ? library
          : testLibrary(child: child, root: library.root);
      await showLibrary(tester, shelf);
      if (find.text(fileName).evaluate().isEmpty) {
        await importBook(tester, shelf, fileName);
      }
      await openShelfBook(tester, fileName);
      expect(view().controller.isBookLoaded.value, isTrue);
    }

    Future<void> openFromContents(int index) async {
      await tester.tap(find.byTooltip('Contents'));
      await tester.pumpAndSettle();
      final title = view().controller.tableOfContents()[index].title!;
      final entry = find.widgetWithText(ListTile, title);
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
    }

    await openReader();
    final total = view().controller.tableOfContents().length;
    expect(find.text('Chapter 1 of $total'), findsOneWidget);
    var style = (view().builders.options as DefaultBuilderOptions).textStyle;
    expect(style.fontSize, 24);
    expect(style.height, 1.8);
    await openFromContents(1);
    expect(find.text('Chapter 2 of $total'), findsOneWidget);
    final savedPosition = prefs.getInt('epub_position_Alex_alice.epub');
    expect(savedPosition, greaterThan(0));

    await tester.tap(find.byTooltip('Reading settings'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider).at(0)).onChanged!(26);
    tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(2.0);
    await tester.tap(find.text('Dark Theme'));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('font_size'), 26);
    expect(prefs.getDouble('line_height'), 2.0);
    expect(prefs.getString('reader_theme'), 'dark');
    Navigator.of(tester.element(find.text('Reading Settings'))).pop();
    await tester.pumpAndSettle();
    style = (view().builders.options as DefaultBuilderOptions).textStyle;
    expect(style.fontSize, 26);
    expect(style.height, 2.0);
    expect(style.color, const Color(0xFFF0F0F0));

    await openReader();
    expect(view().controller.currentValue?.position.index, savedPosition);
    expect(find.text('Chapter 2 of $total'), findsOneWidget);
    expect(
      (view().builders.options as DefaultBuilderOptions).textStyle.fontSize,
      26,
    );
    await openFromContents(0);
    expect(find.text('Chapter 1 of $total'), findsOneWidget);

    // The tracker is read-only; only the contents menu navigates.
    expect(find.byType(Slider), findsNothing);
    expect(find.text('${total - 1} chapters left'), findsOneWidget);
    // Tracker sits above the book text.
    final readerTop = tester.getTopLeft(find.byType(EpubView)).dy;
    expect(
      tester.getBottomLeft(find.text('${total - 1} chapters left')).dy,
      lessThanOrEqualTo(readerTop),
    );
    expect(find.byTooltip('Previous'), findsNothing);
    expect(find.byTooltip('Next'), findsNothing);
    await openFromContents(2);
    expect(find.text('Chapter 3 of $total'), findsOneWidget);
    expect(find.text('${total - 3} chapters left'), findsOneWidget);
    await openFromContents(total - 1);
    expect(find.text('Chapter $total of $total'), findsOneWidget);
    expect(find.text('Last chapter!'), findsOneWidget);
    // Finish book fades away while the child scrolls, then comes back.
    double finishOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Finish book'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(EpubView)),
    );
    await drag.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(finishOpacity(), 0);
    await drag.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(finishOpacity(), 1);
    expect(
      (jsonDecode(prefs.getString('activity_log_Alex')!) as List).where(
        (event) => event['type'] == 'book_finished',
      ),
      isEmpty,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish book'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(quizBook, 'alice.epub');
    expect(quizText, contains('Down the Rabbit-Hole'));
    expect(quizText, isNot(contains('PROJECT GUTENBERG LICENSE')));
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Question →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A well'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Keep Reading →'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(EpubView), findsOneWidget);

    final events = jsonDecode(prefs.getString('activity_log_Alex')!) as List;
    expect(events.map((event) => event['type']), [
      'book_opened',
      'book_opened',
      'book_finished',
      'comprehension_result',
    ]);
    expect(events.last['title'], 'alice.epub');
    expect(events.last['score'], '1/2');
    expect(events.last['ts'], isA<int>());
    expect(prefs.getString('activity_log_Sam'), isNull);

    // Another child or another filename must not inherit Alex's position.
    await openReader(child: 'Sam');
    expect(find.text('Chapter 1 of $total'), findsOneWidget);
    fileName = 'different.epub';
    await openReader();
    expect(find.text('Chapter 1 of $total'), findsOneWidget);

    // Repeated finishes still count as one distinct book in the parent view.
    events.add(events.firstWhere((event) => event['type'] == 'book_finished'));
    await prefs.setString('activity_log_Alex', jsonEncode(events));
    final fb = signedIn();
    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Alex', pin: '1234'),
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(home: ParentDashboardScreen(store: fb.store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Alex scored 1/2 on "alice.epub"'), findsOneWidget);
    expect(find.text('Alex finished "alice.epub"'), findsNWidgets(2));
    expect(find.text('0'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
