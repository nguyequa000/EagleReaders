import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/login_screen.dart';
import 'package:storysprout/screens/parent_or_child_screen.dart';
import 'package:storysprout/services/session_prefs.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  // "Keep me signed in" is stored in shared preferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wrong credentials show an error and do not navigate', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    whenCalling(
      Invocation.method(#signInWithEmailAndPassword, null),
    ).on(auth).thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
    await tester.enterText(find.byType(TextField).first, 'parent@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrongpass');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(ParentOrChildScreen), findsNothing);
  });

  testWidgets('valid credentials sign in and navigate to the persona screen', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();

    await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
    await tester.enterText(find.byType(TextField).first, 'parent@example.com');
    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNotNull);
    expect(find.byType(ParentOrChildScreen), findsOneWidget);
  });

  testWidgets('empty fields are rejected before any auth call', (tester) async {
    final auth = MockFirebaseAuth();

    await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pump();

    expect(find.text('Enter your email and password.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  group('keep me signed in', () {
    Future<void> logIn(WidgetTester tester, MockFirebaseAuth auth) async {
      await tester.enterText(
        find.byType(TextField).first,
        'parent@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'hunter2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle();
    }

    testWidgets('is ticked by default and remembered with the email', (
      tester,
    ) async {
      final auth = MockFirebaseAuth();
      await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
      await tester.pumpAndSettle();

      final box = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Keep me signed in'),
      );
      expect(box.value, isTrue);
      await logIn(tester, auth);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SessionPrefs.keepSignedInKey), isTrue);
      expect(prefs.getString(SessionPrefs.emailKey), 'parent@example.com');
    });

    testWidgets('unticking it is remembered too', (tester) async {
      final auth = MockFirebaseAuth();
      await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep me signed in'));
      await tester.pump();
      await logIn(tester, auth);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SessionPrefs.keepSignedInKey), isFalse);
      expect(prefs.getString(SessionPrefs.emailKey), 'parent@example.com');
    });

    testWidgets('a failed sign-in remembers nothing', (tester) async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#signInWithEmailAndPassword, null),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await tester.pumpWidget(wrap(LoginScreen(auth: auth)));
      await tester.pumpAndSettle();
      await logIn(tester, auth);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    testWidgets('the remembered email is filled in, the password is not', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        SessionPrefs.emailKey: 'parent@example.com',
        SessionPrefs.keepSignedInKey: false,
      });
      await tester.pumpWidget(wrap(LoginScreen(auth: MockFirebaseAuth())));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.first.controller!.text, 'parent@example.com');
      expect(fields.last.controller!.text, isEmpty);
      final box = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Keep me signed in'),
      );
      expect(box.value, isFalse);
    });
  });
}
