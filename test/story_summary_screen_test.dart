import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/screens/story_character_screen.dart';

void main() {
  const config = StoryConfig(
    character: 'Brave Knight',
    mood: 'Funny',
    setting: 'Forest',
  );

  testWidgets('shows all 3 story choices', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );
    expect(find.text('Brave Knight'), findsOneWidget);
    expect(find.text('Funny'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
  });

  testWidgets('shows Start Reading button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );
    expect(find.text('Start Reading!'), findsOneWidget);
  });

  testWidgets('tapping Start Reading calls onStartReading with full config', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(
          config: config,
          onStartReading: (c) => result = c,
        ),
      ),
    );
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();
    expect(result?.character, 'Brave Knight');
    expect(result?.mood, 'Funny');
    expect(result?.setting, 'Forest');
  });
}
