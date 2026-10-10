import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';

import 'test_helpers.dart';

/// The child's real books: the ones they're reading on the home tab, and
/// every one of them in My Library.
void main() {
  late FamilySettings settings;

  setUp(() {
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;
    settings = FamilySettings(firestore: fb.firestore, auth: fb.auth);
    FamilySettings.instance = settings;
  });
  tearDown(() => FamilySettings.instance = FamilySettings());

  Book book(String title, {int added = 0, int? opened, int chapter = 0}) =>
      Book(
        id: title,
        title: title,
        author: 'An Author',
        filePath: '/nowhere/$title.epub',
        chapter: chapter,
        chaptersTotal: 12,
        addedAt: added,
        lastOpenedAt: opened,
      );

  /// A shelf for child '1', the way BookLibrary stores it.
  void shelf(List<Book> books) => SharedPreferences.setMockInitialValues({
    'book_library_1': jsonEncode([for (final b in books) b.toJson()]),
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ChildDashboardScreen(childId: '1', childName: 'Mika'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.text('My Library'));
    await tester.pumpAndSettle();
  }

  testWidgets('Currently Reading has the books they have opened', (
    tester,
  ) async {
    shelf([
      book('Alice in Wonderland', added: 1, opened: 50, chapter: 3),
      book('Treasure Island', added: 2),
    ]);
    await pumpDashboard(tester);

    expect(find.text('Currently Reading'), findsOneWidget);
    expect(find.text('My Books'), findsNothing);
    expect(find.text('Alice in Wonderland'), findsOneWidget);
    expect(find.text('Chapter 3 of 12'), findsOneWidget);
    // Not started yet, so it waits in My Library.
    expect(find.text('Treasure Island'), findsNothing);
    expect(find.text('See all 2 books'), findsOneWidget);
  });

  testWidgets('the book they were last in comes first', (tester) async {
    shelf([
      book('Old Favourite', added: 1, opened: 10),
      book('Just Opened', added: 30, opened: 40),
      book('Reading Now', added: 2, opened: 99),
    ]);
    await pumpDashboard(tester);

    double x(String title) => tester.getTopLeft(find.text(title)).dx;
    double y(String title) => tester.getTopLeft(find.text(title)).dy;
    // Two columns: Reading Now, Just Opened, then Old Favourite below.
    expect(x('Reading Now'), lessThan(x('Just Opened')));
    expect(y('Old Favourite'), greaterThan(y('Reading Now')));
  });

  testWidgets('nothing opened yet points to My Library', (tester) async {
    shelf([book('Treasure Island')]);
    await pumpDashboard(tester);

    expect(find.byKey(const Key('nothing-being-read')), findsOneWidget);
    await tester.tap(find.text('Open My Library'));
    await tester.pumpAndSettle();
    expect(find.text('Treasure Island'), findsOneWidget);
    expect(find.text('Ready to read'), findsOneWidget);
  });

  testWidgets('My Library has every book, A to Z', (tester) async {
    shelf([
      for (var i = 1; i <= 6; i++) book('Book $i', added: i, opened: i),
      book('A New One', added: 7),
    ]);
    await pumpDashboard(tester);

    // Home shows four of the six being read.
    expect(find.text('Book 6'), findsOneWidget);
    expect(find.text('Book 2'), findsNothing);
    expect(find.text('A New One'), findsNothing);
    await tester.ensureVisible(find.text('See all 7 books'));
    await tester.tap(find.text('See all 7 books'));
    await tester.pumpAndSettle();

    for (final title in ['A New One', 'Book 1', 'Book 2', 'Book 6']) {
      await tester.ensureVisible(find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    double y(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(y('A New One'), lessThan(y('Book 6')));
  });

  testWidgets('back from My Library goes Home', (tester) async {
    shelf([book('Treasure Island')]);
    await pumpDashboard(tester);
    await openLibrary(tester);
    expect(find.byKey(const Key('nothing-being-read')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nothing-being-read')), findsOneWidget);
  });

  testWidgets('an empty shelf says so', (tester) async {
    shelf([]);
    await pumpDashboard(tester);
    expect(find.byKey(const Key('no-books')), findsOneWidget);
    expect(
      find.text('Ask a grown-up to add some books for you.'),
      findsOneWidget,
    );
    await openLibrary(tester);
    expect(find.byKey(const Key('no-books')), findsOneWidget);
  });

  testWidgets('books wait too when the daily limit is used up', (tester) async {
    shelf([book('Alice in Wonderland')]);
    await settings.saveChild('1', const ChildRules(dailyLimitMinutes: 15));
    await ActivityService.instance.logEvent('1', 'reading_session', {
      'title': 'Alice in Wonderland',
      'minutes': 30,
    });
    await pumpDashboard(tester);
    await openLibrary(tester);

    await tester.ensureVisible(find.text('Alice in Wonderland'));
    await tester.tap(find.text('Alice in Wonderland'));
    await tester.pumpAndSettle();
    expect(
      find.text("You've used today's reading time. Come back tomorrow!"),
      findsOneWidget,
    );
  });
}
