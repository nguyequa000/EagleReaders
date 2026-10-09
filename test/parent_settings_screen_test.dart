import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_rules_screen.dart';
import 'package:storysprout/screens/parent_settings_screen.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/reader_audience.dart';

void main() {
  late MockUser user;
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;
  late FamilySettings settings;
  late ChildProfileStore store;

  // A fresh uid per test: mock_exceptions matches stubs by equality, and two
  // MockUsers with the same fields are equal, so a stub would leak forward.
  var run = 0;

  setUp(() {
    // ChildProfileStore.load() checks prefs for legacy profiles.
    SharedPreferences.setMockInitialValues({});
    user = MockUser(uid: 'parent-${run++}', email: 'sam.parent@example.com');
    auth = MockFirebaseAuth(signedIn: true, mockUser: user);
    firestore = FakeFirebaseFirestore();
    settings = FamilySettings(firestore: firestore, auth: auth);
    store = ChildProfileStore(firestore: firestore, auth: auth);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ParentSettingsScreen(
          auth: auth,
          settings: settings,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('greets the parent by email until they set a name', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Hello, sam.parent'), findsOneWidget);

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Sam'), findsOneWidget);
    expect(await settings.loadDisplayName(), 'Sam');
  });

  testWidgets('every switch is saved and comes back on reopening', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.widget<Switch>(switchFor('AI reading quizzes')).value, true);
    expect(tester.widget<Switch>(switchFor('Reading Reminders')).value, false);

    for (final label in [
      'AI story writing',
      'AI reading quizzes',
      "Sprout's writing ideas",
      'Read Aloud',
      'Reading Reminders',
    ]) {
      await tester.ensureVisible(switchFor(label));
      await tester.tap(switchFor(label));
      await tester.pumpAndSettle();
    }

    final saved = await FamilySettings(firestore: firestore, auth: auth).load();
    expect(saved.aiStories, isFalse);
    expect(saved.aiQuizzes, isFalse);
    expect(saved.sproutIdeas, isFalse);
    expect(saved.readAloud, isFalse);
    expect(saved.readingReminder, isTrue);

    // A fresh screen shows what was saved.
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(tester.widget<Switch>(switchFor('AI story writing')).value, false);
    expect(tester.widget<Switch>(switchFor('Reading Reminders')).value, true);
  });

  group('Change Password', () {
    Future<void> fill(
      WidgetTester tester, {
      String current = 'old-pass',
      String next = 'new-pass1',
      String? confirm,
    }) async {
      await tapText(tester, 'Change Password');
      await tester.enterText(
        find.byKey(const Key('current-password')),
        current,
      );
      await tester.enterText(find.byKey(const Key('new-password')), next);
      await tester.enterText(
        find.byKey(const Key('confirm-password')),
        confirm ?? next,
      );
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
    }

    testWidgets('succeeds and says so', (tester) async {
      await pump(tester);
      await fill(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Your password has been changed.'), findsOneWidget);
    });

    testWidgets('a wrong current password is shown in the dialog', (
      tester,
    ) async {
      whenCalling(
        Invocation.method(#reauthenticateWithCredential, null),
      ).on(user).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await pump(tester);
      await fill(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Your current password is incorrect.'), findsOneWidget);
    });

    testWidgets('mismatched new passwords never reach Firebase', (
      tester,
    ) async {
      whenCalling(
        Invocation.method(#updatePassword, null),
      ).on(user).thenThrow(FirebaseAuthException(code: 'should-not-call'));
      await pump(tester);
      await fill(tester, confirm: 'different');
      expect(find.text("The new passwords don't match."), findsOneWidget);
    });

    testWidgets('a weak new password is explained', (tester) async {
      await pump(tester);
      await fill(tester, next: '123');
      expect(
        find.text('Use at least 6 characters for the new password.'),
        findsOneWidget,
      );
    });
  });

  group('Change Email', () {
    Future<void> fill(WidgetTester tester, String email) async {
      await tapText(tester, 'Change Email');
      await tester.enterText(find.byKey(const Key('new-email')), email);
      await tester.enterText(
        find.byKey(const Key('current-password')),
        'old-pass',
      );
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends a link to the new address', (tester) async {
      await pump(tester);
      await fill(tester, 'new@example.com');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          'Check new@example.com for a link to finish changing your email.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an email already in use is explained', (tester) async {
      whenCalling(
        Invocation.method(#verifyBeforeUpdateEmail, null),
      ).on(user).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      await pump(tester);
      await fill(tester, 'taken@example.com');
      expect(
        find.text('Another account already uses that email.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Age Restrictions and Time Limit set each child\'s rules', (
    tester,
  ) async {
    await store.save([
      ChildProfile.withPin(id: 'kid-1', name: 'Mika', pin: '1234'),
      ChildProfile.withPin(id: 'kid-2', name: 'Salma', pin: '1234'),
    ]);
    await pump(tester);

    await tapText(tester, 'Age Restrictions');
    expect(find.byType(ChildRulesScreen), findsOneWidget);
    expect(find.textContaining('Mika'), findsOneWidget);
    expect(find.textContaining('Salma'), findsOneWidget);

    await tester.tap(find.byKey(const Key('age-kid-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ages 3–5').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('limit-kid-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutes').last);
    await tester.pumpAndSettle();

    expect((await settings.loadChild('kid-1')).ageBand, AgeBand.ages3to5);
    expect((await settings.loadChild('kid-1')).dailyLimitMinutes, isNull);
    expect((await settings.loadChild('kid-2')).dailyLimitMinutes, 30);
    expect((await settings.loadChild('kid-2')).ageBand, AgeBand.fallback);

    // Time Limit opens the same screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Time Limit');
    expect(find.byType(ChildRulesScreen), findsOneWidget);
    expect(find.text('Ages 3–5'), findsOneWidget);
  });
}
