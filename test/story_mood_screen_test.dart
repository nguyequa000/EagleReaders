import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_scene.dart';
import 'package:storysprout/screens/story/hero_preview.dart';
import 'package:storysprout/screens/story_mood_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story/story_option_grid.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  const config = StoryConfig();

  testWidgets('shows all 4 mood options', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StoryMoodScreen(config: config)));
    expect(find.text('Funny'), findsOneWidget);
    expect(find.text('Adventurous'), findsOneWidget);
    expect(find.text('Spooky'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('Next button is present but disabled before selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StoryMoodScreen(config: config)));
    expect(find.text('Next'), findsOneWidget);

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a mood enables the Next button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StoryMoodScreen(config: config)));
    final before = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Funny'));
    await tester.pump();

    // The button is always present post-redesign, so its mere existence proves
    // nothing. What changes on selection is that it becomes pressable.
    final after = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(after.onPressed, isNotNull);
  });

  testWidgets('tapping Next passes character and mood in StoryConfig', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryMoodScreen(config: config, onNext: (c) => result = c),
      ),
    );
    await tester.tap(find.text('Spooky'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(result?.hero, isNotNull);
    expect(result?.mood, 'Spooky');
  });

  testWidgets('step 2 puts the one action colour on button and grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StoryMoodScreen(config: config)));

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    final grid = tester.widget<StoryOptionGrid>(find.byType(StoryOptionGrid));
    // One action colour across the whole flow: the step no longer changes it.
    expect(button.accent, StoryPalette.light.action);
    expect(grid.accent, StoryPalette.light.action);
  });

  testWidgets('an incoming mood is highlighted and enables Next', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: StoryMoodScreen(config: StoryConfig(mood: 'Spooky')),
      ),
    );

    // Stepping Back into this screen must not discard the child's choice.
    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(button.onPressed, isNotNull);

    final grid = tester.widget<StoryOptionGrid>(find.byType(StoryOptionGrid));
    expect(grid.selectedLabel, 'Spooky');
  });

  testWidgets('a seeded mood carries through Next untouched', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryMoodScreen(
          config: const StoryConfig(mood: 'Calm'),
          onNext: (c) => result = c,
        ),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(result?.mood, 'Calm');
  });

  testWidgets('the hero is shown wearing the face the mood calls for', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: StoryMoodScreen(config: StoryConfig())),
    );
    await tester.pump();

    String? moodOf() =>
        tester.widget<HeroPreview>(find.byType(HeroPreview)).mood;

    expect(find.byType(HeroPreview), findsOneWidget);
    expect(moodOf(), isNull, reason: 'nothing chosen yet');

    await tester.tap(find.text('Spooky'));
    await tester.pump();

    // The choice has to show its own consequence rather than being a label
    // taken on trust. The hero's pose belongs to the child, so what the mood
    // changes is the light in the scene behind them.
    expect(moodOf(), 'Spooky');
    expect(
      StoryScene.forest.forMood('Spooky').skyTop,
      isNot(StoryScene.forest.forMood('Calm').skyTop),
    );
  });
}
