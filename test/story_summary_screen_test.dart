import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:storysprout/screens/story/hero_preview.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  const config = StoryConfig(mood: 'Funny', setting: 'Forest');

  testWidgets('shows all 3 story choices', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );

    expect(find.text('Funny'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
  });

  testWidgets('shows Start Reading button', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );
    expect(find.text('Start Reading!'), findsOneWidget);
  });

  testWidgets('tapping Start Reading calls onStartReading with full config', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    StoryConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(
          config: config,
          onStartReading: (c) => result = c,
        ),
      ),
    );
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();
    expect(result?.hero, isNotNull);
    expect(result?.mood, 'Funny');
    expect(result?.setting, 'Forest');
  });

  testWidgets('shows the illustration matching each selected option', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: StorySummaryScreen(
          config: StoryConfig(mood: 'Spooky', setting: 'Ocean'),
        ),
      ),
    );
    await tester.pump();

    // The hero is an SvgPicture too, but string-loaded rather than
    // asset-loaded, so only the bundled illustrations are collected here.
    final assets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => picture.bytesLoader)
        .whereType<SvgAssetLoader>()
        .map((loader) => loader.assetName)
        .toList();

    expect(assets, contains('assets/story/moods/spooky.svg'));
    expect(assets, contains('assets/story/settings/ocean.svg'));

    // The bug this covers: these were previously hardcoded to funny/forest.
    expect(assets, isNot(contains('assets/story/moods/funny.svg')));
    expect(assets, isNot(contains('assets/story/settings/forest.svg')));
  });

  testWidgets(
    'a choice left unmade degrades to an em dash instead of throwing',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: StorySummaryScreen(config: StoryConfig())),
      );
      await tester.pump();

      // Mood and Setting were never chosen — no crash, and each renders '—'.
      expect(find.text('—'), findsNWidgets(2));

      // Neither unmade choice gets an illustration. The hero still renders,
      // because it is generated rather than chosen.
      final assets = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((picture) => picture.bytesLoader)
          .whereType<SvgAssetLoader>()
          .toList();
      expect(assets, isEmpty);
      expect(find.byType(HeroPreview), findsOneWidget);
    },
  );

  testWidgets('each row keeps the tint from its own step', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );

    Color borderColorFor(String caption) {
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(caption),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).border != null,
              ),
            )
            .first,
      );
      final border = (container.decoration as BoxDecoration).border as Border;
      return border.top.color;
    }

    // Every row is cut out with the same ink line; what distinguishes them
    // is the tint each one carries through from its own step.
    expect(borderColorFor('Feeling'), StoryPalette.light.outline);
    expect(borderColorFor('Place'), StoryPalette.light.outline);

    Color fillFor(String caption) {
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(caption),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            )
            .first,
      );
      return (container.decoration as BoxDecoration).color!;
    }

    expect(
      fillFor('Feeling'),
      isNot(fillFor('Place')),
      reason: 'each choice keeps the tint it wore on its own step',
    );
  });

  testWidgets('naming the hero carries the name into the story', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    StoryConfig? started;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(
          config: config,
          onStartReading: (c) => started = c,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('NAME YOUR HERO'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sprout');
    await tester.pump();
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();

    expect(started?.hero.name, 'Sprout');
  });

  testWidgets('a hero left unnamed is still allowed to start', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    StoryConfig? started;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(
          config: config,
          onStartReading: (c) => started = c,
        ),
      ),
    );
    await tester.pump();

    // Whitespace is not a name, and a four-year-old who cannot spell yet must
    // not be blocked from their own story.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text('Start Reading!'));
    await tester.pump();

    expect(started, isNotNull);
    expect(started?.hero.name, isNull);
  });

  testWidgets('Edit hero offers a way back to the builder', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(config: config, onEditHero: () => edits++),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Edit hero'));
    await tester.pump();
    expect(edits, 1);
  });
}
