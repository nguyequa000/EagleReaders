import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_option.dart';
import 'package:storysprout/screens/story/story_option_grid.dart';
import 'package:storysprout/screens/story/story_scaffold.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  Future<void> pumpScaffold(
    WidgetTester tester, {
    int step = 1,
    String sectionLabel = 'CHOOSE YOUR CHARACTER',
    VoidCallback? onBack,
    Widget? footer,
    Widget? child,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: StoryScaffold(
        step: step,
        prompt: 'Pick one',
        sectionLabel: sectionLabel,
        onBack: onBack,
        footer: footer,
        child: child ?? const SizedBox(height: 100),
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows the step counter in the new format', (tester) async {
    await pumpScaffold(tester, step: 2);
    expect(find.text('STEP 2 OF 4'), findsOneWidget);
  });

  testWidgets('shows the section label verbatim', (tester) async {
    await pumpScaffold(tester);
    expect(find.text('CHOOSE YOUR CHARACTER'), findsOneWidget);
  });

  testWidgets('shows the Sprout prompt', (tester) async {
    await pumpScaffold(tester);
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets('exposes a back control that fires onBack', (tester) async {
    var backs = 0;
    await pumpScaffold(tester, onBack: () => backs++);

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });

  testWidgets('paints the ground colour', (tester) async {
    await pumpScaffold(tester);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, StoryTheme.ground);
  });

  testWidgets('lays out a real StoryOptionGrid child without throwing',
      (tester) async {
    await pumpScaffold(
      tester,
      step: 1,
      child: StoryOptionGrid(
        options: StoryOptions.characters,
        selectedLabel: null,
        accent: StoryTheme.accentForStep(1),
        onSelect: (_) {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StoryOptionGrid), findsOneWidget);
  });

  testWidgets('accent changes with the step', (tester) async {
    // Step 1 is indigo and step 2 is amber; they must differ from one
    // another, and the progress bar's filled segment(s) must actually use
    // the accent for the step currently rendered (not a hardcoded colour).
    expect(StoryTheme.accentForStep(1), isNot(StoryTheme.accentForStep(2)));

    await pumpScaffold(tester, step: 1);
    final containersAtStep1 = tester.widgetList<Container>(find.byType(Container));
    final hasAccent1 = containersAtStep1.any((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.color == StoryTheme.accentForStep(1);
    });
    expect(hasAccent1, isTrue);

    await pumpScaffold(tester, step: 2);
    final containersAtStep2 = tester.widgetList<Container>(find.byType(Container));
    final hasAccent2 = containersAtStep2.any((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.color == StoryTheme.accentForStep(2);
    });
    expect(hasAccent2, isTrue);
  });

  testWidgets('progress bar fills segments where i < step', (tester) async {
    await pumpScaffold(tester, step: 3);

    final accent = StoryTheme.accentForStep(3);
    final containers = tester.widgetList<Container>(find.byType(Container));

    final filledCount = containers.where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.color == accent &&
          decoration.borderRadius == BorderRadius.circular(3);
    }).length;

    // Segment containers use height 6 and a 3-radius pill shape; at step 3
    // of 4 total steps, exactly 3 should be filled with the accent colour.
    expect(filledCount, 3);
  });

  testWidgets('footer renders when provided', (tester) async {
    await pumpScaffold(
      tester,
      footer: const Text('Continue', key: Key('footer-text')),
    );
    expect(find.byKey(const Key('footer-text')), findsOneWidget);
  });

  testWidgets('footer is absent when null', (tester) async {
    await pumpScaffold(tester);
    expect(find.byKey(const Key('footer-text')), findsNothing);
  });
}
