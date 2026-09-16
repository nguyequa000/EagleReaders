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

  /// Taps a label after scrolling it into view.
  ///
  /// The steps are taller than the viewport once a preview box sits above the
  /// options, so targets low on the screen start off-screen, where a plain tap
  /// silently misses instead of failing.
  Future<void> tapLabel(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('starts on step 1 — the hero builder', (tester) async {
    await pumpFlow(tester);
    expect(find.text('Build your hero!'), findsOneWidget);
    expect(find.text('STEP 1 OF 4'), findsOneWidget);
  });

  testWidgets('tapping Next advances to step 2', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A MOOD'), findsOneWidget);
    expect(find.text('STEP 2 OF 4'), findsOneWidget);
  });

  testWidgets('back on step 2 returns to the hero builder', (tester) async {
    await pumpFlow(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A MOOD'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Build your hero!'), findsOneWidget);
  });

  testWidgets('completing all steps calls onComplete with full config', (tester) async {
    StoryConfig? result;
    await pumpFlow(tester, onComplete: (c) => result = c);

    // Step 1
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2
    await tapLabel(tester, 'Spooky');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3
    await tapLabel(tester, 'Ocean');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4
    await tapLabel(tester, 'Start Reading!');

    expect(result?.hero, isNotNull);
    expect(result?.mood, 'Spooky');
    expect(result?.setting, 'Ocean');
  });

  testWidgets('stepping back to step 2 keeps the chosen mood live', (
    tester,
  ) async {
    await pumpFlow(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tapLabel(tester, 'Spooky');
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

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tapLabel(tester, 'Calm');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tapLabel(tester, 'Ocean');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Back to step 3, then straight on without re-picking.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A SETTING'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Start Reading!');

    expect(result?.hero, isNotNull);
    expect(result?.mood, 'Calm');
    expect(result?.setting, 'Ocean');
  });

  // Regression cover for the back-button trap: reaching the story used to leave
  // all four steps on the stack, so getting out meant tapping back four times.
  group('leaving a finished story', () {
    // Stands in for the child dashboard, so we can assert we actually land back
    // on it rather than somewhere inside the flow.
    Future<void> pumpFromDashboard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoryFlowScreen()),
              ),
              child: const Text('DASHBOARD'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();
    }

    Future<void> buildAStory(WidgetTester tester) async {
      // Step 1 needs no choice at all — a seeded hero is already whole — so
      // it contributes only its Next tap.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      for (final choice in ['Spooky', 'Ocean']) {
        await tapLabel(tester, choice);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Start Reading!'));
      await tester.pumpAndSettle();
    }

    Future<void> turnThePage(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
    }

    testWidgets('the page-turn arrow opens the what-next screen', (
      tester,
    ) async {
      await pumpFromDashboard(tester);
      await buildAStory(tester);

      expect(find.text('Your Story'), findsOneWidget);
      await turnThePage(tester);

      expect(find.text('The End!'), findsOneWidget);
      expect(find.text('Create Another Story'), findsOneWidget);
      expect(find.text('Return Home'), findsOneWidget);
    });

    testWidgets('Return Home lands on the dashboard, not inside the flow', (
      tester,
    ) async {
      await pumpFromDashboard(tester);
      await buildAStory(tester);
      await turnThePage(tester);

      await tester.tap(find.text('Return Home'));
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Build your hero!'), findsNothing);
      expect(find.text('Your Story'), findsNothing);
    });

    testWidgets('Create Another Story restarts at step 1 with no selections', (
      tester,
    ) async {
      await pumpFromDashboard(tester);
      await buildAStory(tester);
      await turnThePage(tester);

      await tester.tap(find.text('Create Another Story'));
      await tester.pumpAndSettle();

      expect(find.text('Build your hero!'), findsOneWidget);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
    });

    testWidgets(
      'back from step 1 of a second story goes home, not to the old story',
      (tester) async {
        await pumpFromDashboard(tester);
        await buildAStory(tester);
        await turnThePage(tester);

        await tester.tap(find.text('Create Another Story'));
        await tester.pumpAndSettle();
        expect(find.text('Build your hero!'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Starting a second story must not leave the first one sitting under
        // the new flow — backing out of step 1 belongs at the dashboard.
        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.text('Your Story'), findsNothing);
      },
    );

    testWidgets('back from the what-next screen returns to the story', (
      tester,
    ) async {
      await pumpFromDashboard(tester);
      await buildAStory(tester);
      await turnThePage(tester);

      // Tapping the arrow by accident must be recoverable.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Your Story'), findsOneWidget);
      expect(find.textContaining('Once upon a time'), findsOneWidget);
    });

    testWidgets('the four steps are gone from the stack once reading', (
      tester,
    ) async {
      await pumpFromDashboard(tester);
      await buildAStory(tester);

      // One pop from the reader lands on the dashboard, not on step 4.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD'), findsOneWidget);
    });
  });
}
