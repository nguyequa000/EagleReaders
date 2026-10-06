import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_setting_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story/story_option_grid.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  const config = StoryConfig(mood: 'Funny');

  testWidgets('shows all 4 setting options', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );
    expect(find.text('Forest'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Outer Space'), findsOneWidget);
  });

  testWidgets('Next button is present but disabled before selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );
    expect(find.text('Next'), findsOneWidget);

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a setting enables the Next button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );
    final before = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Forest'));
    await tester.pump();

    // The button is always present post-redesign, so its mere existence proves
    // nothing. What changes on selection is that it becomes pressable.
    final after = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(after.onPressed, isNotNull);
  });

  testWidgets('tapping Next passes full StoryConfig with setting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySettingScreen(config: config, onNext: (c) => result = c),
      ),
    );
    await tester.tap(find.text('Outer Space'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(result?.hero, isNotNull);
    expect(result?.mood, 'Funny');
    expect(result?.setting, 'Outer Space');
  });

  testWidgets('step 3 puts the one action colour on button and grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );

    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    final grid = tester.widget<StoryOptionGrid>(find.byType(StoryOptionGrid));
    // One action colour across the whole flow: the step no longer changes it.
    expect(button.accent, StoryPalette.light.action);
    expect(grid.accent, StoryPalette.light.action);
  });

  testWidgets('an incoming setting is highlighted and enables Next', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: StorySettingScreen(
          config: StoryConfig(mood: 'Funny', setting: 'Ocean'),
        ),
      ),
    );

    // Stepping Back into this screen must not discard the child's choice.
    final button = tester.widget<StoryButton>(find.byType(StoryButton));
    expect(button.onPressed, isNotNull);

    final grid = tester.widget<StoryOptionGrid>(find.byType(StoryOptionGrid));
    expect(grid.selectedLabel, 'Ocean');
  });

  testWidgets('a seeded setting carries through Next untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySettingScreen(
          config: const StoryConfig(mood: 'Funny', setting: 'City'),
          onNext: (c) => result = c,
        ),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(result?.setting, 'City');
  });
}
