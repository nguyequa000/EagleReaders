import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:storysprout/screens/login_screen.dart';
import 'package:storysprout/screens/parent_or_child_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

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
}
