import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_character_screen.dart';

void main() {
  setUp(() {});

  testWidgets('shows all 4 character options', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: StoryCharacterScreen()),
    );
    expect(find.text('Brave Knight'), findsOneWidget);
    expect(find.text('Friendly Dragon'), findsOneWidget);
    expect(find.text('Clever Fox'), findsOneWidget);
    expect(find.text('Magic Fairy'), findsOneWidget);
  });

  testWidgets('Next button hidden before selection', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: StoryCharacterScreen()),
    );
    expect(find.text('Next →'), findsNothing);
  });

  testWidgets('selecting a character shows Next button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: StoryCharacterScreen()),
    );
    await tester.tap(find.text('Brave Knight'));
    await tester.pump();
    expect(find.text('Next →'), findsOneWidget);
  });

  testWidgets('tapping Next calls onNext with selected character', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryCharacterScreen(
          onNext: (config) => result = config,
        ),
      ),
    );
    await tester.tap(find.text('Clever Fox'));
    await tester.pump();
    await tester.tap(find.text('Next →'));
    await tester.pump();
    expect(result?.character, 'Clever Fox');
  });
}
