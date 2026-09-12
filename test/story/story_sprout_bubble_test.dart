import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_sprout_bubble.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  testWidgets('renders the message it is given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StorySproutBubble(
          message: 'Who is your story about?',
          accent: StoryTheme.accentCharacter,
        ),
      ),
    ));

    expect(find.text('Who is your story about?'), findsOneWidget);
  });

  testWidgets('message text uses the body face', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StorySproutBubble(
          message: 'Pick a mood',
          accent: StoryTheme.accentMood,
        ),
      ),
    ));

    final text = tester.widget<Text>(find.text('Pick a mood'));
    expect(text.style!.fontFamily, 'Nunito');
  });

  testWidgets('avatar keeps the sprout emoji, not an illustration',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StorySproutBubble(
          message: 'Hello!',
          accent: StoryTheme.accentSetting,
        ),
      ),
    ));

    expect(find.text('🌱'), findsOneWidget);
  });

  testWidgets('avatar ring uses the given accent colour', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StorySproutBubble(
          message: 'Hello!',
          accent: StoryTheme.accentComplete,
        ),
      ),
    ));

    final avatar = tester.widget<Container>(
      find.ancestor(
        of: find.text('🌱'),
        matching: find.byType(Container),
      ),
    );
    final decoration = avatar.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.color, StoryTheme.accentComplete);
  });

  testWidgets('bubble corner is asymmetric to form a tail toward the avatar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StorySproutBubble(
          message: 'Hello!',
          accent: StoryTheme.accentCharacter,
        ),
      ),
    ));

    final bubble = tester.widget<Container>(
      find.ancestor(
        of: find.text('Hello!'),
        matching: find.byType(Container),
      ),
    );
    final decoration = bubble.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius.topLeft, const Radius.circular(4));
    expect(radius.topRight, const Radius.circular(StoryTheme.radiusTile));
    expect(radius.bottomLeft, const Radius.circular(StoryTheme.radiusTile));
    expect(radius.bottomRight, const Radius.circular(StoryTheme.radiusTile));
  });
}
