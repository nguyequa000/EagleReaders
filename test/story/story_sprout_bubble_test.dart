import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_sprout_bubble.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  testWidgets('renders the message it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorySproutBubble(
            message: 'Who is your story about?',
            accent: StoryPalette.light.action,
          ),
        ),
      ),
    );

    expect(find.text('Who is your story about?'), findsOneWidget);
  });

  testWidgets('message text uses the body face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorySproutBubble(
            message: 'Pick a mood',
            accent: StoryPalette.light.action,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Pick a mood'));
    expect(text.style!.fontFamily, 'Nunito');
  });

  testWidgets('avatar keeps the sprout emoji, not an illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorySproutBubble(
            message: 'Hello!',
            accent: StoryPalette.light.action,
          ),
        ),
      ),
    );

    expect(find.text('🌱'), findsOneWidget);
  });

  testWidgets('avatar is cut out with the flow ink line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorySproutBubble(
            message: 'Hello!',
            accent: StoryPalette.light.action,
          ),
        ),
      ),
    );

    final avatar = tester.widget<Container>(
      find.ancestor(of: find.text('🌱'), matching: find.byType(Container)),
    );
    final decoration = avatar.decoration as BoxDecoration;
    final border = decoration.border as Border;
    // Sprout wears the same line as the stickers rather than an accent ring:
    // a lone accent circle read as a control the child could press.
    expect(border.top.color, StoryPalette.light.outline);
    expect(border.top.width, StoryTheme.outlineWidth);
  });

  testWidgets('bubble corner is asymmetric to form a tail toward the avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorySproutBubble(
            message: 'Hello!',
            accent: StoryPalette.light.action,
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      find.ancestor(of: find.text('Hello!'), matching: find.byType(Container)),
    );
    final decoration = bubble.decoration as BoxDecoration;
    final radius = decoration.borderRadius as BorderRadius;
    expect(radius.topLeft, const Radius.circular(4));
    expect(radius.topRight, const Radius.circular(StoryTheme.radiusTile));
    expect(radius.bottomLeft, const Radius.circular(StoryTheme.radiusTile));
    expect(radius.bottomRight, const Radius.circular(StoryTheme.radiusTile));
  });
}
