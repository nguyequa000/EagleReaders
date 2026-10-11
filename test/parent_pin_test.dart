import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_setup_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/parent_pin_screen.dart';
import 'package:storysprout/screens/registration_screen.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/parent_pin.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ParentPin.instance = ParentPin());

  group('ParentPin store', () {
    test('a set PIN verifies, a wrong one does not', () async {
      final fb = signedIn();
      final pins = ParentPin(firestore: fb.firestore, auth: fb.auth);
      expect(await pins.isSet(), isFalse);

      await pins.set('4821');

      expect(await pins.isSet(), isTrue);
      expect(await pins.verify('4821'), isTrue);
      expect(await pins.verify('1234'), isFalse);
    });

    test(
      'only a salted hash is stored, beside the other parent fields',
      () async {
        final fb = signedIn();
        await fb.firestore.collection('parents').doc('parent-1').set({
          'email': 'p@example.com',
          'role': 'parent',
        });
        await ParentPin(firestore: fb.firestore, auth: fb.auth).set('4821');

        final data =
            (await fb.firestore.collection('parents').doc('parent-1').get())
                .data()!;
        expect(data['email'], 'p@example.com', reason: 'merged, not replaced');
        expect(data['pinHash'], isA<String>());
        expect(data['pinSalt'], isA<String>());
        expect(data.values, isNot(contains('4821')));
      },
    );

    test('nothing verifies when no PIN was ever set', () async {
      final fb = signedIn();
      final pins = ParentPin(firestore: fb.firestore, auth: fb.auth);
      expect(await pins.verify('1234'), isFalse);
      expect(await pins.verify(''), isFalse);
    });
  });

  group('registration', () {
    Future<void> fillIn(
      WidgetTester tester, {
      String pin = '4821',
      String confirm = '4821',
    }) async {
      await tester.enterText(
        find.byKey(const Key('register-email')),
        'newparent@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'hunter2',
      );
      await tester.enterText(find.byKey(const Key('register-pin')), pin);
      await tester.enterText(
        find.byKey(const Key('register-pin-confirm')),
        confirm,
      );
      await tester.ensureVisible(find.widgetWithText(StoryButton, 'Register'));
      await tester.tap(find.widgetWithText(StoryButton, 'Register'));
      await tester.pumpAndSettle();
    }

    testWidgets('a new account is created with the parent PIN it chose', (
      tester,
    ) async {
      final auth = MockFirebaseAuth();
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(auth: auth, firestore: firestore),
        ),
      );
      await fillIn(tester);

      expect(find.byType(ChildSetupScreen), findsOneWidget);
      final pins = ParentPin(firestore: firestore, auth: auth);
      expect(await pins.verify('4821'), isTrue);
      expect(await pins.verify('1234'), isFalse);
    });

    testWidgets('a PIN that is not four digits is refused', (tester) async {
      final auth = MockFirebaseAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            auth: auth,
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      );
      await fillIn(tester, pin: '12', confirm: '12');

      expect(find.text('Choose a 4-digit parent PIN.'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('PINs that do not match are refused', (tester) async {
      final auth = MockFirebaseAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            auth: auth,
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      );
      await fillIn(tester, confirm: '4822');

      expect(find.text("The two PINs don't match."), findsOneWidget);
      expect(auth.currentUser, isNull);
    });
  });

  group('parent PIN screen', () {
    setUp(() {
      final f = signedIn();
      ActivityService.instance = f.activity;
      CoinService.instance = f.coins;
      FamilySettings.instance = FamilySettings(
        firestore: f.firestore,
        auth: f.auth,
      );
      ParentPin.instance = ParentPin(firestore: f.firestore, auth: f.auth);
    });
    tearDown(() => FamilySettings.instance = FamilySettings());

    Future<void> enter(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.tap(find.widgetWithText(StoryButton, 'Enter'));
      await tester.pumpAndSettle();
    }

    testWidgets('the PIN set at sign-up opens the dashboard', (tester) async {
      await ParentPin.instance.set('4821');
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();

      await enter(tester, '1234');
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(find.byType(ParentDashboardScreen), findsNothing);

      await enter(tester, '4821');
      expect(find.byType(ParentDashboardScreen), findsOneWidget);
    });

    testWidgets('an account with no PIN yet is asked to create one', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ParentPinScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create a parent PIN'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4821');
      await tester.tap(find.widgetWithText(StoryButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Type it again'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4822');
      await tester.tap(find.widgetWithText(StoryButton, 'Save PIN'));
      await tester.pumpAndSettle();
      expect(find.text("Those didn't match. Start again."), findsOneWidget);
      expect(await ParentPin.instance.isSet(), isFalse);

      await tester.enterText(find.byType(TextField), '4821');
      await tester.tap(find.widgetWithText(StoryButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4821');
      await tester.tap(find.widgetWithText(StoryButton, 'Save PIN'));
      await tester.pumpAndSettle();

      expect(find.byType(ParentDashboardScreen), findsOneWidget);
      expect(await ParentPin.instance.verify('4821'), isTrue);
    });
  });
}
