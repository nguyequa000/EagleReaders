import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_setting_screen.dart';
import 'package:storysprout/screens/story_character_screen.dart';

void main() {
  const config = StoryConfig(character: 'Brave Knight', mood: 'Funny');

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

  testWidgets('Next button hidden before selection', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );
    expect(find.text('Next →'), findsNothing);
  });

  testWidgets('selecting a setting shows Next button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(config: config)),
    );
    await tester.tap(find.text('Forest'));
    await tester.pump();
    expect(find.text('Next →'), findsOneWidget);
  });

  testWidgets('tapping Next passes full StoryConfig with setting', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySettingScreen(
          config: config,
          onNext: (c) => result = c,
        ),
      ),
    );
    await tester.tap(find.text('Outer Space'));
    await tester.pump();
    await tester.tap(find.text('Next →'));
    await tester.pump();
    expect(result?.character, 'Brave Knight');
    expect(result?.mood, 'Funny');
    expect(result?.setting, 'Outer Space');
  });
}
