import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_profile_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';

import 'test_helpers.dart';

void main() {
  // ChildProfileStore.load checks local storage for legacy profiles.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Parent opens the child profile from View and returns', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Alex', pin: '1234'),
    ]);
    final activity = fb.firestore
        .collection('parents')
        .doc('parent-1')
        .collection('children')
        .doc('1')
        .collection('activity');
    for (final event in [
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
    ]) {
      await activity.add(event);
    }

    await tester.pumpWidget(
      MaterialApp(home: ParentDashboardScreen(store: fb.store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reading: alice.epub'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'View'));
    await tester.pumpAndSettle();

    expect(find.byType(ChildProfileScreen), findsOneWidget);
    expect(find.text("Alex's Profile"), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // minutes this week
    expect(find.text('50%'), findsOneWidget); // last quiz score
    expect(find.text('Currently reading'), findsOneWidget);
    expect(find.text('alice.epub'), findsOneWidget);
    expect(find.text('Alex scored 1/2 on "alice.epub"'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Parent Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Child profile renders safely with no activity', (tester) async {
    ActivityService.instance = signedIn().activity;
    await tester.pumpWidget(
      const MaterialApp(
        home: ChildProfileScreen(childId: '1', childName: 'Alex'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No quiz yet'), findsOneWidget);
    expect(find.text('Nothing right now'), findsOneWidget);
    expect(find.text('No activity yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
