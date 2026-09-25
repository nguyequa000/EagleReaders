import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/login_screen.dart';

void main() {
  testWidgets('Login screen displays the actual app entry UI', (tester) async {
    // Replaces the generated counter test, whose MyApp no longer exists.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Story Sprout'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
