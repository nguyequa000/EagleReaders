import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_theme.dart';
import 'package:storysprout/services/story_generator.dart';

void main() {
  Future<void> pumpReader(
    WidgetTester tester, {
    StoryConfig? config,
    VoidCallback? onNextPage,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config:
              config ??
              const StoryConfig(
                hero: HeroConfig(name: 'Fox'),
                mood: 'Spooky',
                setting: 'Ocean',
              ),
          onNextPage: onNextPage,
          // The offline story, so no test reaches for the AI.
          generate: (config, {soFar, choice}) async => fallbackStory(config),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('paints the shared ground colour', (tester) async {
    await pumpReader(tester);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, StoryPalette.light.ground);
  });

  testWidgets('names the three choices in the preview banner', (tester) async {
    await pumpReader(tester);
    expect(find.textContaining('Fox'), findsWidgets);
    expect(find.textContaining('Spooky'), findsWidgets);
    expect(find.textContaining('Ocean'), findsWidgets);
  });

  testWidgets('story body uses the body face', (tester) async {
    await pumpReader(tester);
    final body = tester.widget<Text>(find.textContaining('Once upon a time'));
    expect(body.style!.fontFamily, 'Nunito');
  });

  testWidgets('banner values read as ink, and captions as muted', (
    tester,
  ) async {
    await pumpReader(tester);

    // The three banner lines used to be tinted one accent each. With a single
    // action colour, colour no longer distinguishes them — the caption does,
    // so the values are plain ink and only the captions recede.
    for (final value in <String>['Fox', 'Spooky', 'Ocean']) {
      expect(
        tester.widget<Text>(find.text(value)).style!.color,
        StoryPalette.light.ink,
        reason: value,
      );
    }
    expect(
      tester.widget<Text>(find.text('Mood: ')).style!.color,
      StoryPalette.light.inkMuted,
    );
  });

  testWidgets(
    'a config with null fields renders the unknown fallback without throwing',
    (tester) async {
      await pumpReader(tester, config: const StoryConfig());

      expect(tester.takeException(), isNull);
      // Mood and Setting fall back; the hero does not, because an unnamed hero
      // is still a hero rather than a missing choice.
      expect(find.text('unknown'), findsNWidgets(2));
      expect(find.text('Your hero'), findsOneWidget);
    },
  );

  // The reader is the end of the story flow. It replaces the 4-step flow in the
  // stack rather than sitting on top of it, so there is nothing behind it to go
  // back to — the page-turn arrow is the only way onward.
  group('page turn', () {
    testWidgets('shows the next-page arrow when wired up', (tester) async {
      await pumpReader(tester, onNextPage: () {});

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('the arrow fires its callback', (tester) async {
      var turns = 0;
      await pumpReader(tester, onNextPage: () => turns++);

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      expect(turns, 1);
    });

    testWidgets('shows no arrow when not wired up', (tester) async {
      await pumpReader(tester);

      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('carries no exit buttons in the body', (tester) async {
      await pumpReader(tester, onNextPage: () {});

      expect(find.text('Done'), findsNothing);
      expect(find.text('Return Home'), findsNothing);
      expect(find.text('Create Another Story'), findsNothing);
    });

    testWidgets('blocks back-navigation so the flow cannot be re-entered', (
      tester,
    ) async {
      await pumpReader(tester, onNextPage: () {});

      // PopScope is generic; match any type argument.
      final popScope =
          tester.widgetList(find.byWidgetPredicate((w) => w is PopScope)).single
              as PopScope;
      expect(popScope.canPop, isFalse);
    });

    testWidgets('allows back when there is no page to turn to', (tester) async {
      await pumpReader(tester);

      final popScope =
          tester.widgetList(find.byWidgetPredicate((w) => w is PopScope)).single
              as PopScope;
      expect(popScope.canPop, isTrue);
    });

    testWidgets('has no AppBar back arrow', (tester) async {
      await pumpReader(tester, onNextPage: () {});

      expect(find.byType(BackButton), findsNothing);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
    });
  });
}
