import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_setup_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('defaults to one child; count dropdown adds rows', (
    tester,
  ) async {
    final ctx = signedIn();
    await tester.pumpWidget(wrap(ChildSetupScreen(store: ctx.store)));

    // 1 name + 1 PIN field.
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('valid entries are saved and navigate to the dashboard', (
    tester,
  ) async {
    final ctx = signedIn();
    await tester.pumpWidget(wrap(ChildSetupScreen(store: ctx.store)));

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Emma');
    await tester.enterText(fields.at(1), '1111');
    await tester.enterText(fields.at(2), 'Noah');
    await tester.enterText(fields.at(3), '2222');

    final done = find.widgetWithText(ElevatedButton, 'Done');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(find.byType(ParentDashboardScreen), findsOneWidget);

    final saved = await ctx.store.load();
    expect(saved.map((c) => c.name), ['Emma', 'Noah']);
    expect(saved[0].verifyPin('1111'), isTrue);
    expect(saved[1].verifyPin('2222'), isTrue);
  });

  testWidgets('a blank name or short PIN blocks saving', (tester) async {
    final ctx = signedIn();
    await tester.pumpWidget(wrap(ChildSetupScreen(store: ctx.store)));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Emma');
    await tester.enterText(fields.at(1), '12'); // too short
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pump();

    expect(
      find.text('Give each child a name and a 4-digit PIN.'),
      findsOneWidget,
    );
    expect(find.byType(ParentDashboardScreen), findsNothing);
    expect(await ctx.store.load(), isEmpty);
  });
}
