import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';

void main() {
  Future<void> pumpFlow(WidgetTester tester, {void Function(StoryConfig)? onComplete}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StoryFlowScreen(onComplete: onComplete)),
    );
  }

  testWidgets('starts on step 1 — character selection', (tester) async {
    await pumpFlow(tester);
    expect(find.text('CHOOSE YOUR CHARACTER'), findsOneWidget);
    expect(find.text('STEP 1 OF 4'), findsOneWidget);
  });

  testWidgets('selecting a character and tapping Next advances to step 2', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Brave Knight'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A MOOD'), findsOneWidget);
    expect(find.text('STEP 2 OF 4'), findsOneWidget);
  });

  testWidgets('back on step 2 returns to step 1', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Brave Knight'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE YOUR CHARACTER'), findsOneWidget);
  });

  testWidgets('completing all steps calls onComplete with full config', (tester) async {
    StoryConfig? result;
    await pumpFlow(tester, onComplete: (c) => result = c);

    // Step 1
    await tester.tap(find.text('Clever Fox'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2
    await tester.tap(find.text('Spooky'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3
    await tester.tap(find.text('Ocean'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();

    expect(result?.character, 'Clever Fox');
    expect(result?.mood, 'Spooky');
    expect(result?.setting, 'Ocean');
  });

  testWidgets('stepping back to step 2 keeps the chosen mood live', (
    tester,
  ) async {
    await pumpFlow(tester);

    await tester.tap(find.text('Brave Knight'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spooky'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A SETTING'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A MOOD'), findsOneWidget);

    // The mood is still chosen, so Next must work without re-picking it.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A SETTING'), findsOneWidget);
  });

  testWidgets('stepping back to step 3 keeps the chosen setting live', (
    tester,
  ) async {
    StoryConfig? result;
    await pumpFlow(tester, onComplete: (c) => result = c);

    await tester.tap(find.text('Clever Fox'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calm'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ocean'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Back to step 3, then straight on without re-picking.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A SETTING'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();

    expect(result?.character, 'Clever Fox');
    expect(result?.mood, 'Calm');
    expect(result?.setting, 'Ocean');
  });
}
