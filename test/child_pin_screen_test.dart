import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/screens/child_pin_screen.dart';
import 'package:storysprout/services/child_profiles.dart';

void main() {
  const child = ChildProfile(id: '1', name: 'Alex', pin: '4321');

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('correct PIN opens the child dashboard', (tester) async {
    await tester.pumpWidget(wrap(const ChildPinScreen(child: child)));
    await tester.enterText(find.byType(TextField), '4321');
    await tester.tap(find.widgetWithText(ElevatedButton, "Let's Go! 🚀"));
    await tester.pumpAndSettle();

    expect(find.byType(ChildDashboardScreen), findsOneWidget);
  });

  testWidgets('wrong PIN shows an error and does not navigate', (tester) async {
    await tester.pumpWidget(wrap(const ChildPinScreen(child: child)));
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.widgetWithText(ElevatedButton, "Let's Go! 🚀"));
    await tester.pump();

    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect(find.byType(ChildDashboardScreen), findsNothing);
  });
}
