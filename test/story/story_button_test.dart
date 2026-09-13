import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    expect(_translateOffsetOf(tester), Offset.zero);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StoryButton)),
    );
    await tester.pump();
    expect(_decorationOf(tester).boxShadow, isEmpty);
    expect(_translateOffsetOf(tester), const Offset(0, StoryTheme.depth));

    await gesture.up();
    await tester.pump();
    expect(_decorationOf(tester).boxShadow, isNotEmpty);
    expect(_translateOffsetOf(tester), Offset.zero);
  });

  testWidgets('shows the forward arrow by default', (tester) async {
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentCharacter,
        onPressed: () {},
      ),
    ));

    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('hides the forward arrow when showArrow is false',
      (tester) async {
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Start Reading!',
        accent: StoryTheme.accentCharacter,
        onPressed: () {},
        showArrow: false,
      ),
    ));

    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('announces its label once, not twice', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentCharacter,
        onPressed: () {},
      ),
    ));

    // The button wraps its own Text in a Semantics node. Without
    // excludeSemantics the two merge and a screen reader says "Next, Next".
    expect(find.bySemanticsLabel('Next'), findsOneWidget);

    final node = tester.getSemantics(find.bySemanticsLabel('Next'));
    expect(node.label, 'Next');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);

    handle.dispose();
  });

  testWidgets('a disabled button still announces its label once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(
      const StoryButton(label: 'Next', accent: StoryTheme.accentCharacter),
    ));

    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Next'));
    expect(node.label, 'Next');
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);

    handle.dispose();
  });

  // excludeSemantics discards the child GestureDetector's tap action, so the
  // Semantics node has to declare its own. Reading the button is useless if a
  // screen reader cannot also activate it — assert the action fires, not just
  // that the flag is set.
  testWidgets('a screen reader can actually activate the button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(wrap(
      StoryButton(
        label: 'Next',
        accent: StoryTheme.accentCharacter,
        onPressed: () => taps++,
      ),
    ));

    final node = tester.getSemantics(find.bySemanticsLabel('Next'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('Next'));
    await tester.pump();

    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a disabled button advertises no tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(
      const StoryButton(label: 'Next', accent: StoryTheme.accentCharacter),
    ));

    final node = tester.getSemantics(find.bySemanticsLabel('Next'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    handle.dispose();
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

Offset _translateOffsetOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byType(StoryButton),
      matching: find.byType(Transform),
    ).first,
  );
  return MatrixUtils.getAsTranslation(transform.transform) ?? Offset.zero;
}
