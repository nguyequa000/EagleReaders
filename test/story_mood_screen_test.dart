import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_mood_screen.dart';
import 'package:storysprout/screens/story_character_screen.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story/story_option_grid.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  const config = StoryConfig(character: 'Brave Knight');

  testWidgets('shows all 4 mood options', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StoryMoodScreen(config: config)),
    );
    expect(find.text('Funny'), findsOneWidget);
    expect(find.text('Adventurous'), findsOneWidget);
    expect(find.text('Spooky'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('Next button is present but disabled before selection', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StoryMoodScreen(config: config)),
    );
    expect(find.text('Next'), findsOneWidget);

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a mood shows Next button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StoryMoodScreen(config: config)),
    );
    await tester.tap(find.text('Funny'));
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('tapping Next passes character and mood in StoryConfig', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryMoodScreen(
          config: config,
          onNext: (c) => result = c,
        ),
      ),
    );
    await tester.tap(find.text('Spooky'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(result?.character, 'Brave Knight');
    expect(result?.mood, 'Spooky');
  });

  testWidgets('step 2 uses the amber mood accent on both button and grid', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StoryMoodScreen(config: config)),
    );

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    final grid = tester.widget<StoryOptionGrid>(find.byType(StoryOptionGrid));
    expect(button.accent, StoryTheme.accentForStep(2));
    expect(grid.accent, StoryTheme.accentForStep(2));
    expect(StoryTheme.accentForStep(2), isNot(StoryTheme.accentForStep(3)));
  });
}
