import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story/story_finished_screen.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  Future<void> pumpFinished(
    WidgetTester tester, {
    VoidCallback? onCreateAnother,
    VoidCallback? onReturnHome,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: StoryFinishedScreen(
        onCreateAnother: onCreateAnother ?? () {},
        onReturnHome: onReturnHome ?? () {},
      ),
    ));
    await tester.pump();
  }

  testWidgets('offers exactly the two choices', (tester) async {
    await pumpFinished(tester);

    expect(find.text('Create Another Story'), findsOneWidget);
    expect(find.text('Return Home'), findsOneWidget);
    expect(find.byType(StoryButton), findsNWidgets(2));
  });

  testWidgets('Create Another Story fires its callback', (tester) async {
    var another = 0;
    await pumpFinished(tester, onCreateAnother: () => another++);

    await tester.tap(find.text('Create Another Story'));
    await tester.pump();

    expect(another, 1);
  });

  testWidgets('Return Home fires its callback', (tester) async {
    var home = 0;
    await pumpFinished(tester, onReturnHome: () => home++);

    await tester.tap(find.text('Return Home'));
    await tester.pump();

    expect(home, 1);
  });

  testWidgets('asks the child what they want to do', (tester) async {
    await pumpFinished(tester);

    expect(
      find.textContaining('finished your story'),
      findsOneWidget,
      reason: 'Sprout should prompt, matching the rest of the flow',
    );
  });

  testWidgets('uses the shared ground colour', (tester) async {
    await pumpFinished(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, StoryTheme.ground);
  });

  testWidgets('keeps a back control so the story can be re-read', (
    tester,
  ) async {
    await pumpFinished(tester);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(
      appBar.automaticallyImplyLeading,
      isTrue,
      reason: 'tapping the arrow by accident must be recoverable',
    );
  });
}
