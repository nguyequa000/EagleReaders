import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders its label', (tester) async {
    await tester.pumpWidget(wrap(
      const StoryButton(label: 'Next', accent: StoryTheme.accentCharacter),
    ));
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentCharacter,
        onPressed: () => taps++,
      ),
    ));

    await tester.tap(find.byType(StoryButton));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('uses the accent when enabled and the disabled tone when not',
      (tester) async {
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentMood,
        onPressed: () {},
      ),
    ));
    expect(_fillOf(tester), StoryTheme.accentMood);

    await tester.pumpWidget(wrap(
      const StoryButton(label: 'Next', accent: StoryTheme.accentMood),
    ));
    expect(_fillOf(tester), StoryTheme.disabled);
  });

  testWidgets('shadow collapses while held down', (tester) async {
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentCharacter,
        onPressed: () {},
      ),
    ));

    expect(_decorationOf(tester).boxShadow, isNotEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StoryButton)),
    );
    await tester.pump();
    expect(_decorationOf(tester).boxShadow, isEmpty);

    await gesture.up();
    await tester.pump();
    expect(_decorationOf(tester).boxShadow, isNotEmpty);
  });
}

BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(StoryButton),
      matching: find.byType(Container),
    ).first,
  );
  return container.decoration! as BoxDecoration;
}

Color _fillOf(WidgetTester tester) => _decorationOf(tester).color!;
