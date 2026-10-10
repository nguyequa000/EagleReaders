import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_mode_screen.dart';

void main() {
  Future<List<WriterLevel>> pump(
    WidgetTester tester, {
    VoidCallback? onBack,
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);
    final chosen = <WriterLevel>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StoryModeScreen(onBack: onBack, onChoose: chosen.add),
      ),
    );
    await tester.pump();
    return chosen;
  }

  testWidgets('offers both writer levels', (tester) async {
    await pump(tester);
    expect(find.text('Beginning writer'), findsOneWidget);
    expect(find.text('Advanced writer'), findsOneWidget);
    expect(find.text('Sprout writes the story with you.'), findsOneWidget);
    expect(
      find.text('You write the story. Sprout gives ideas.'),
      findsOneWidget,
    );
  });

  testWidgets('each card reports its level', (tester) async {
    final chosen = await pump(tester);
    await tester.tap(find.text('Beginning writer'));
    await tester.tap(find.text('Advanced writer'));
    expect(chosen, [WriterLevel.beginning, WriterLevel.advanced]);
  });

  testWidgets('cards are buttons to a screen reader, at least 48px tall', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    for (final label in ['Beginning writer', 'Advanced writer']) {
      final card = find.bySemanticsLabel(RegExp('^$label'));
      expect(card, findsOneWidget);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    }
    handle.dispose();
  });

  testWidgets('Back calls onBack', (tester) async {
    var backs = 0;
    await pump(tester, onBack: () => backs++);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backs, 1);
  });

  // The same sizes story_no_scroll_test holds every step to.
  for (final size in const [Size(500, 900), Size(430, 840)]) {
    testWidgets('fits without scrolling at ${size.width}x${size.height}', (
      tester,
    ) async {
      await pump(tester, size: size);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, 0);
    });
  }

  // Smaller phones may scroll, but both cards must be built and reachable.
  for (final size in const [Size(375, 667), Size(360, 640)]) {
    testWidgets('both cards reachable at ${size.width}x${size.height}', (
      tester,
    ) async {
      final chosen = await pump(tester, size: size);
      for (final label in ['Beginning writer', 'Advanced writer']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
      }
      expect(chosen, [WriterLevel.beginning, WriterLevel.advanced]);
    });
  }
}
