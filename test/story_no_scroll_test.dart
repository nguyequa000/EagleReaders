import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story_flow_screen.dart';

/// Every step has to fit without scrolling on a normal phone.
///
/// This is a stated requirement, not a nicety: a child who cannot see the
/// Next button does not know the step is finished. It has regressed twice —
/// once when the preview box was added above the options, and again when the
/// sticker styling made the header, buttons and progress beads chunkier — so
/// the sizes are pinned here rather than re-measured by hand each time.
///
/// Smaller phones than these do scroll, which is unavoidable at 667px tall
/// with a preview, four options and a footer. That is safe because the step
/// body scrolls rather than clips; the failure being guarded against is the
/// content silently running past the bottom edge at a size people actually
/// use.
void main() {
  for (final size in const <Size>[
    // The window the design was reviewed at, and one notch down.
    Size(500, 900),
    Size(430, 840),
  ]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('no step needs scrolling at $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 44);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: StoryFlowScreen()));
      await tester.pump();

      void expectFits(int step) {
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        expect(
          position.maxScrollExtent,
          0,
          reason:
              'step $step scrolls '
              '${position.maxScrollExtent.toStringAsFixed(1)}px at $name',
        );
      }

      Future<void> choose(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pump();
      }

      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expectFits(1);
      await next();

      expectFits(2);
      await choose('Ocean');
      await next();

      expectFits(3);
      await choose('Spooky');
      await next();

      expectFits(4);
    });
  }
}
