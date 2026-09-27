import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_pin_screen.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/screens/child_selector_screen.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('renders a button per stored child and opens its PIN screen', (
    tester,
  ) async {
    final ctx = signedIn();
    await ctx.store.save([
      ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111'),
      ChildProfile.withPin(id: 'b', name: 'Noah', pin: '2222'),
    ]);

    await tester.pumpWidget(wrap(ChildSelectorScreen(store: ctx.store)));
    await tester.pumpAndSettle();

    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Noah'), findsOneWidget);

    await tester.tap(find.text('Emma'));
    await tester.pumpAndSettle();

    expect(find.byType(ChildPinScreen), findsOneWidget);
    expect(find.text('Hi Emma!'), findsOneWidget);
  });

  testWidgets('shows an empty state when no children are stored', (
    tester,
  ) async {
    final ctx = signedIn();

    await tester.pumpWidget(wrap(ChildSelectorScreen(store: ctx.store)));
    await tester.pumpAndSettle();

    expect(find.text('No child profiles yet.'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
}
