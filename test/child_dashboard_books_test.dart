import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/screens/reading_library_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';

import 'test_helpers.dart';

/// The child's real books on their home tab, in place of the old demo cards.
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

  testWidgets('the books a grown-up added are on the home tab', (tester) async {
    shelf([
      book('Alice in Wonderland', added: 1, opened: 50, chapter: 3),
      book('Treasure Island', added: 2),
    ]);
    await pumpDashboard(tester);

    expect(find.text('My Books'), findsOneWidget);
    expect(find.text('Alice in Wonderland'), findsOneWidget);
    expect(find.text('Chapter 3 of 12'), findsOneWidget);
    expect(find.text('Treasure Island'), findsOneWidget);
    expect(find.text('Ready to read'), findsOneWidget);
    // The demo placeholders are gone.
    expect(find.text('The Tiny Seed'), findsNothing);
    expect(find.text('Continue Reading'), findsNothing);
  });

  testWidgets('the book they were last in comes first', (tester) async {
    shelf([
      book('Old Favourite', added: 1, opened: 10),
      book('Just Added', added: 30),
      book('Reading Now', added: 2, opened: 99),
    ]);
    await pumpDashboard(tester);

    double x(String title) => tester.getTopLeft(find.text(title)).dx;
    double y(String title) => tester.getTopLeft(find.text(title)).dy;
    // Two columns: Reading Now, Just Added, then Old Favourite below.
    expect(x('Reading Now'), lessThan(x('Just Added')));
    expect(y('Old Favourite'), greaterThan(y('Reading Now')));
  });

  testWidgets('more than four books: the rest are a tap away', (tester) async {
    shelf([for (var i = 1; i <= 6; i++) book('Book $i', added: i)]);
    await pumpDashboard(tester);

    expect(find.text('Book 6'), findsOneWidget);
    expect(find.text('Book 2'), findsNothing);
    await tester.ensureVisible(find.text('See all 6 books'));
    await tester.tap(find.text('See all 6 books'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingLibraryScreen), findsOneWidget);
  });

  testWidgets('an empty shelf says so', (tester) async {
    shelf([]);
    await pumpDashboard(tester);
    expect(find.byKey(const Key('no-books')), findsOneWidget);
    expect(
      find.text('Ask a grown-up to add some books for you.'),
      findsOneWidget,
    );
  });

  testWidgets('books wait too when the daily limit is used up', (tester) async {
    shelf([book('Alice in Wonderland')]);
    await settings.saveChild('1', const ChildRules(dailyLimitMinutes: 15));
    await ActivityService.instance.logEvent('1', 'reading_session', {
      'title': 'Alice in Wonderland',
      'minutes': 30,
    });
    await pumpDashboard(tester);

    await tester.ensureVisible(find.text('Alice in Wonderland'));
    await tester.tap(find.text('Alice in Wonderland'));
    await tester.pumpAndSettle();
    expect(
      find.text("You've used today's reading time. Come back tomorrow!"),
      findsOneWidget,
    );
  });
}
