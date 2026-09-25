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
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/reading_module_page.dart';

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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(home: ReadingModulePage(childName: child)),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Choose File'));
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.pump();
          if (find.byType(EpubView).evaluate().isNotEmpty &&
              view().controller.isBookLoaded.value) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(view().controller.isBookLoaded.value, isTrue);
    }

    await openReader();
    final total = view().controller.tableOfContents().length;
    expect(find.text('Chapter 1 of $total'), findsOneWidget);
    var style = (view().builders.options as DefaultBuilderOptions).textStyle;
    expect(style.fontSize, 24);
    expect(style.height, 1.8);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 of $total'), findsOneWidget);

    // The footer tracker is read-only; only the contents menu and
    // Previous/Next buttons navigate the EPUB document.
    expect(find.byType(Slider), findsNothing);
    expect(find.text('${total - 1} chapters left'), findsOneWidget);
    // Tracker sits above the book text; navigation stays below it.
    final readerTop = tester.getTopLeft(find.byType(EpubView)).dy;
    expect(
      tester.getBottomLeft(find.text('${total - 1} chapters left')).dy,
      lessThanOrEqualTo(readerTop),
    );
    expect(
      tester.getTopLeft(find.text('Previous')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(EpubView)).dy),
    );
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

    await openFromContents(2);
    expect(find.text('Chapter 3 of $total'), findsOneWidget);
    expect(find.text('${total - 3} chapters left'), findsOneWidget);
    await openFromContents(total - 1);
    expect(find.text('Chapter $total of $total'), findsOneWidget);
    expect(find.text('Last chapter!'), findsOneWidget);
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
    await tester.tap(find.text('Water and sunlight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Question →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In a city'));
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
    await tester.pumpWidget(const MaterialApp(home: ParentDashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Alex scored 1/2 on "alice.epub"'), findsOneWidget);
    expect(find.text('Alex finished "alice.epub"'), findsNWidgets(2));
    expect(find.text('0'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
