import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_profile_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/reading_library_screen.dart';
import 'package:storysprout/services/child_profiles.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Parent opens the child profile from View and returns', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'activity_log_Alex': jsonEncode([
        {'type': 'book_opened', 'ts': now - 3000, 'title': 'alice.epub'},
        {
          'type': 'reading_session',
          'ts': now - 2000,
          'title': 'alice.epub',
          'minutes': 12,
          'bookType': 'epub',
        },
        {
          'type': 'comprehension_result',
          'ts': now - 1000,
          'title': 'alice.epub',
          'score': '1/2',
          'correct': 1,
          'total': 2,
        },
      ]),
    });

    final fb = signedIn();
    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Alex', pin: '1234'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: ParentDashboardScreen(store: fb.store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'View'));
    await tester.pumpAndSettle();

    expect(find.byType(ChildProfileScreen), findsOneWidget);
    expect(find.text("Alex's Profile"), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // minutes this week
    expect(find.text('50%'), findsOneWidget); // last quiz score
    expect(find.text('Last opened'), findsOneWidget);
    expect(find.text('alice.epub'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Alex scored 1/2 on "alice.epub"'),
      200,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Parent Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Child profile renders safely with no activity', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: ChildProfileScreen(childName: 'Alex')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No quiz yet'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No activity yet.'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Only the parent profile view can add books', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: ChildProfileScreen(childName: 'Alex')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Manage Alex's books"));
    await tester.pumpAndSettle();
    final library = tester.widget<ReadingLibraryScreen>(
      find.byType(ReadingLibraryScreen),
    );
    expect(library.childName, 'Alex');
    expect(library.canManage, isTrue);
    expect(find.text('Add Book'), findsOneWidget);
  });
}
