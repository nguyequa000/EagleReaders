import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/login_screen.dart';
import 'package:storysprout/parent_settings_screen.dart';

void main() {
  testWidgets('Sign Out clears the session and returns to the login screen '
      '(TC-FB-WB-004)', (tester) async {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'p1', email: 'parent@example.com'),
    );
    expect(auth.currentUser, isNotNull);

    await tester.pumpWidget(
      MaterialApp(home: ParentSettingsScreen(auth: auth)),
    );
    final signOut = find.widgetWithText(ElevatedButton, 'Sign Out');
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
