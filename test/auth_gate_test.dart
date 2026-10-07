import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/auth_gate.dart';
import 'package:storysprout/screens/login_screen.dart';
import 'package:storysprout/screens/parent_or_child_screen.dart';
import 'package:storysprout/screens/parent_pin_screen.dart';
import 'package:storysprout/services/session_prefs.dart';

void main() {
  MockFirebaseAuth signedInAuth() => MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'parent-1', email: 'parent@example.com'),
  );

  Future<void> openApp(WidgetTester tester, MockFirebaseAuth auth) async {
    await tester.pumpWidget(MaterialApp(home: AuthGate(auth: auth)));
    await tester.pumpAndSettle();
  }

  testWidgets('a kept session opens straight on "Who is reading today?"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SessionPrefs.keepSignedInKey: true,
      SessionPrefs.emailKey: 'parent@example.com',
    });
    final auth = signedInAuth();
    await openApp(tester, auth);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(ParentOrChildScreen), findsOneWidget);
    expect(auth.currentUser, isNotNull);
  });

  testWidgets('a parent who signed in before the checkbox existed stays in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await openApp(tester, signedInAuth());

    expect(find.byType(ParentOrChildScreen), findsOneWidget);
  });

  testWidgets('staying signed in never skips the parent PIN', (tester) async {
    SharedPreferences.setMockInitialValues({
      SessionPrefs.keepSignedInKey: true,
    });
    await openApp(tester, signedInAuth());

    await tester.tap(find.text('Parent'));
    await tester.pumpAndSettle();

    expect(find.byType(ParentPinScreen), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);
    final pin = tester.widget<TextField>(find.byType(TextField));
    expect(pin.controller!.text, isEmpty);

    // Nothing PIN-shaped is ever written to the device.
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys(),
      everyElement(isNot(contains(RegExp('pin', caseSensitive: false)))),
    );
  });

  testWidgets('an unkept session is signed out, leaving only the email', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SessionPrefs.keepSignedInKey: false,
      SessionPrefs.emailKey: 'parent@example.com',
    });
    final auth = signedInAuth();
    await openApp(tester, auth);

    expect(auth.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller!.text, 'parent@example.com');
    expect(fields.last.controller!.text, isEmpty);
  });

  testWidgets('signed out opens on the login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await openApp(tester, MockFirebaseAuth());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ParentOrChildScreen), findsNothing);
  });
}
