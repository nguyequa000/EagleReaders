import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_pin_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/parent_pin_screen.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/parent_pin.dart';
import 'package:storysprout/services/pin_attempts.dart';

import 'test_helpers.dart';

void main() {
  var now = DateTime(2026, 11, 18, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 18, 9);
    PinAttempts.instance = PinAttempts(now: () => now);
  });
  tearDown(() => PinAttempts.instance = PinAttempts());

  group('PinAttempts', () {
    PinAttempts pins() => PinAttempts.instance;

    test('four wrong tries are free, the fifth locks for a minute', () async {
      for (var i = 0; i < 4; i++) {
        expect(await pins().recordFailure('parent'), isNull);
      }
      expect(await pins().lockedFor('parent'), isNull);

      expect(await pins().recordFailure('parent'), const Duration(minutes: 1));
      expect(await pins().lockedFor('parent'), const Duration(minutes: 1));
    });

    test('later wrong tries lock for 5, then 15 minutes', () async {
      for (var i = 0; i < 5; i++) {
        await pins().recordFailure('parent');
      }
      expect(await pins().recordFailure('parent'), const Duration(minutes: 5));
      expect(await pins().recordFailure('parent'), const Duration(minutes: 15));
      expect(await pins().recordFailure('parent'), const Duration(minutes: 15));
    });

    test('a lock runs out', () async {
      for (var i = 0; i < 5; i++) {
        await pins().recordFailure('parent');
      }
      now = now.add(const Duration(seconds: 59));
      expect(await pins().lockedFor('parent'), const Duration(seconds: 1));
      now = now.add(const Duration(seconds: 1));
      expect(await pins().lockedFor('parent'), isNull);
    });

    test('a right PIN starts the count again', () async {
      for (var i = 0; i < 5; i++) {
        await pins().recordFailure('parent');
      }
      await pins().recordSuccess('parent');
      expect(await pins().lockedFor('parent'), isNull);
      for (var i = 0; i < 4; i++) {
        expect(await pins().recordFailure('parent'), isNull);
      }
    });

    test('each child has their own count', () async {
      for (var i = 0; i < 5; i++) {
        await pins().recordFailure(PinAttempts.child('1'));
      }
      expect(await pins().lockedFor(PinAttempts.child('1')), isNotNull);
      expect(await pins().lockedFor(PinAttempts.child('2')), isNull);
      expect(await pins().lockedFor(PinAttempts.parent), isNull);
    });

    test('storage failing never locks anyone out', () async {
      final broken = PinAttempts(prefs: () => Future.error(StateError('x')));
      for (var i = 0; i < 6; i++) {
        expect(await broken.recordFailure('parent'), isNull);
      }
      expect(await broken.lockedFor('parent'), isNull);
    });

    test('the message rounds up to whole minutes', () {
      expect(
        PinAttempts.lockMessage(const Duration(seconds: 5)),
        'Too many tries. Try again in 1 minute.',
      );
      expect(
        PinAttempts.lockMessage(const Duration(minutes: 4, seconds: 1)),
        'Too many tries. Try again in 5 minutes.',
      );
    });
  });

  group('parent PIN screen', () {
    setUp(() async {
      // An email, so "Forgot PIN?" can re-check the account password.
      final f = signedIn(email: 'parent@example.com');
      ActivityService.instance = f.activity;
      CoinService.instance = f.coins;
      FamilySettings.instance = FamilySettings(
        firestore: f.firestore,
        auth: f.auth,
      );
      ParentPin.instance = ParentPin(firestore: f.firestore, auth: f.auth);
      await ParentPin.instance.set('4821');
    });
    tearDown(() {
      FamilySettings.instance = FamilySettings();
      ParentPin.instance = ParentPin();
    });

    Finder enterButton() => find.widgetWithText(StoryButton, 'Enter');

    Future<void> enter(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.tap(enterButton());
      await tester.pumpAndSettle();
    }

    testWidgets('five wrong PINs lock it, even for the right one', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        await enter(tester, '0000');
        expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      }
      await enter(tester, '0000');

      expect(
        find.text('Too many tries. Try again in 1 minute.'),
        findsOneWidget,
      );
      expect(tester.widget<StoryButton>(enterButton()).onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    });

    testWidgets('the lock is still there when the screen is opened again', (
      tester,
    ) async {
      for (var i = 0; i < 5; i++) {
        await PinAttempts.instance.recordFailure(PinAttempts.parent);
      }
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Too many tries. Try again in 1 minute.'),
        findsOneWidget,
      );
    });

    testWidgets('the screen unlocks itself when the lock runs out', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await enter(tester, '0000');
      }
      expect(tester.widget<StoryButton>(enterButton()).onPressed, isNull);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));

      expect(find.textContaining('Too many tries'), findsNothing);
      await enter(tester, '4821');
      expect(find.byType(ParentDashboardScreen), findsOneWidget);
    });

    testWidgets('Forgot PIN: the account password sets a new one', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await enter(tester, '0000');
      }

      await tester.tap(find.byKey(const Key('forgot-parent-pin')));
      await tester.pumpAndSettle();
      expect(find.text('Forgot your PIN?'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('pin-account-password')),
        'hunter2',
      );
      await tester.enterText(find.byKey(const Key('new-parent-pin')), '2468');
      await tester.enterText(
        find.byKey(const Key('confirm-parent-pin')),
        '2468',
      );
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('PIN changed. Enter your new PIN.'), findsOneWidget);
      expect(find.textContaining('Too many tries'), findsNothing);
      expect(await ParentPin.instance.verify('2468'), isTrue);

      await enter(tester, '2468');
      expect(find.byType(ParentDashboardScreen), findsOneWidget);
    });
  });

  group('child PIN screen', () {
    final mika = ChildProfile.withPin(id: '1', name: 'Mika', pin: '4321');
    final salma = ChildProfile.withPin(id: '2', name: 'Salma', pin: '1111');

    Future<void> enter(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.tap(find.text("Let's Go! 🚀"));
      await tester.pumpAndSettle();
    }

    testWidgets('five wrong PINs lock that child only', (tester) async {
      await tester.pumpWidget(MaterialApp(home: ChildPinScreen(child: mika)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await enter(tester, '0000');
      }
      expect(
        find.text('Too many tries. Try again in 1 minute.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChildPinScreen(key: UniqueKey(), child: salma),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many tries'), findsNothing);
    });
  });
}
