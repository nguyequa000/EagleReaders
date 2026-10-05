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

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScaffold(
          step: step,
          prompt: 'Pick one',
          sectionLabel: sectionLabel,
          onBack: onBack,
          footer: footer,
          child: child ?? const SizedBox(height: 100),
        ),
      ),
    );
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
    expect(scaffold.backgroundColor, StoryPalette.light.ground);
  });

  testWidgets('lays out a real StoryOptionGrid child without throwing', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      step: 1,
      child: StoryOptionGrid(
        options: StoryOptions.moods,
        selectedLabel: null,
        accent: StoryPalette.light.action,
        onSelect: (_) {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StoryOptionGrid), findsOneWidget);
  });

  testWidgets('the progress bar fills one segment per completed step', (
    tester,
  ) async {
    // The accent no longer changes per step — there is one action colour — so
    // what the bar encodes is how far along the child is, in how many
    // segments are filled rather than in what colour they are.
    int filledAt(int step) {
      return tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.color == StoryPalette.light.action;
      }).length;
    }

    await pumpScaffold(tester, step: 1);
    final one = filledAt(1);
    expect(one, greaterThan(0));

    await pumpScaffold(tester, step: 3);
    expect(
      filledAt(3),
      greaterThan(one),
      reason: 'further along the flow means more filled segments',
    );
  });

  testWidgets('progress bar fills segments where i < step', (tester) async {
    await pumpScaffold(tester, step: 3);

    final accent = StoryPalette.light.action;
    final containers = tester.widgetList<Container>(find.byType(Container));

    final segments = containers.where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius == BorderRadius.circular(7);
    }).toList();

    // Four chunky beads, cut out with the flow's ink line like everything
    // else on the page, of which exactly 3 are filled at step 3 of 4.
    expect(segments, hasLength(4));
    for (final segment in segments) {
      final decoration = segment.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, StoryPalette.light.outline);
    }
    final filledCount = segments.where((c) {
      return (c.decoration! as BoxDecoration).color == accent;
    }).length;
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
