import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story_character_screen.dart';
import 'package:storysprout/screens/story_mood_screen.dart';
import 'package:storysprout/screens/story_setting_screen.dart';

/// Regression cover for the small-phone layout.
///
/// iPhone SE 2/3 and iPhone 8 are 375x667; a very large slice of Android is
/// 360x640. Every real phone also carries a non-zero status-bar inset. At those
/// sizes the scaffold body is shorter than two rows of tiles need. When the body
/// clips instead of scrolling, the lazy grid never *builds* the second row, so
/// `Clever Fox`, `Magic Fairy`, `Spooky`, `Calm`, `City` and `Outer Space` are
/// unreachable — there is no gesture and no accessibility action that gets to
/// them.
///
/// The rest of the screen suite pins a 400x900 viewport, which is taller than
/// any phone and hides this entirely. These tests pin real phone geometry.
void main() {
  /// Applies a phone viewport with a status-bar inset.
  void usePhone(
    WidgetTester tester, {
    required Size size,
    required double statusBar,
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);
  }

  void useIPhoneSe(WidgetTester tester) =>
      usePhone(tester, size: const Size(375, 667), statusBar: 44);

  void expectAllPresent(List<String> labels) {
    for (final label in labels) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '"$label" must be built and reachable on a small phone',
      );
    }
  }

  group('iPhone SE — 375x667 with a 44px status bar', () {
    testWidgets('step 1 builds all 4 character options', (tester) async {
      useIPhoneSe(tester);
      await tester.pumpWidget(const MaterialApp(home: StoryCharacterScreen()));

      expectAllPresent(const <String>[
        'Brave Knight',
        'Friendly Dragon',
        'Clever Fox',
        'Magic Fairy',
      ]);
    });

    testWidgets('step 2 builds all 4 mood options', (tester) async {
      useIPhoneSe(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryMoodScreen(config: StoryConfig(character: 'Brave Knight')),
        ),
      );

      expectAllPresent(const <String>['Funny', 'Adventurous', 'Spooky', 'Calm']);
    });

    testWidgets('step 3 builds all 4 setting options', (tester) async {
      useIPhoneSe(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: StorySettingScreen(
            config: StoryConfig(character: 'Brave Knight', mood: 'Funny'),
          ),
        ),
      );

      expectAllPresent(const <String>[
        'Forest',
        'Ocean',
        'City',
        'Outer Space',
      ]);
    });
  });

  group('common Android — 360x640 with a 24px status bar', () {
    testWidgets('step 1 builds the second row of characters', (tester) async {
      usePhone(tester, size: const Size(360, 640), statusBar: 24);
      await tester.pumpWidget(const MaterialApp(home: StoryCharacterScreen()));

      expectAllPresent(const <String>['Clever Fox', 'Magic Fairy']);
    });

    testWidgets('step 2 builds the second row of moods', (tester) async {
      usePhone(tester, size: const Size(360, 640), statusBar: 24);
      await tester.pumpWidget(
        const MaterialApp(
          home: StoryMoodScreen(config: StoryConfig(character: 'Brave Knight')),
        ),
      );

      expectAllPresent(const <String>['Spooky', 'Calm']);
    });
  });

  testWidgets('a second-row option is selectable and drives Next on an SE', (
    tester,
  ) async {
    useIPhoneSe(tester);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryCharacterScreen(onNext: (config) => result = config),
      ),
    );

    final fox = find.text('Clever Fox');
    await tester.ensureVisible(fox);
    await tester.pumpAndSettle();
    await tester.tap(fox);
    await tester.pump();

    final next = find.text('Next');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump();

    expect(result?.character, 'Clever Fox');
  });

  testWidgets('the body scroll view scrolls rather than clipping on an SE', (
    tester,
  ) async {
    useIPhoneSe(tester);
    await tester.pumpWidget(const MaterialApp(home: StoryCharacterScreen()));

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ).first,
        )
        .position;
    expect(
      position.maxScrollExtent,
      greaterThan(0.0),
      reason: 'content taller than the viewport must be scrollable, not clipped',
    );
  });

  testWidgets('the body does not scroll when everything fits', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: StoryCharacterScreen()));

    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ).first,
        )
        .position;
    expect(
      position.maxScrollExtent,
      0.0,
      reason: 'the body should grow to fit, not introduce a needless scroll',
    );
  });
}
