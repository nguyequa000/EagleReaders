import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  const config = StoryConfig(
    character: 'Brave Knight',
    mood: 'Funny',
    setting: 'Forest',
  );

  testWidgets('shows all 3 story choices', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StorySummaryScreen(config: config)),
    );
    expect(find.text('Brave Knight'), findsOneWidget);
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

  testWidgets('tapping Start Reading calls onStartReading with full config', (tester) async {
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
    expect(result?.character, 'Brave Knight');
    expect(result?.mood, 'Funny');
    expect(result?.setting, 'Forest');
  });

  testWidgets('shows the illustration matching each selected option',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: StorySummaryScreen(
        config: StoryConfig(
          character: 'Clever Fox',
          mood: 'Spooky',
          setting: 'Ocean',
        ),
      ),
    ));
    await tester.pump();

    final assets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toList();

    expect(assets, contains('assets/story/characters/fox.svg'));
    expect(assets, contains('assets/story/moods/spooky.svg'));
    expect(assets, contains('assets/story/settings/ocean.svg'));

    // The bug this covers: these were previously hardcoded to knight/funny/forest.
    expect(assets, isNot(contains('assets/story/characters/knight.svg')));
    expect(assets, isNot(contains('assets/story/moods/funny.svg')));
    expect(assets, isNot(contains('assets/story/settings/forest.svg')));
  });

  testWidgets(
      'a choice left unmade degrades to an em dash instead of throwing',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: StorySummaryScreen(
        config: StoryConfig(character: 'Magic Fairy'),
      ),
    ));
    await tester.pump();

    // Mood and Setting were never chosen — no crash, and each renders '—'.
    expect(find.text('Magic Fairy'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));

    // Only the one made choice gets an illustration.
    final assets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toList();
    expect(assets, hasLength(1));
    expect(assets, contains('assets/story/characters/fairy.svg'));
  });

  testWidgets('each row is bordered in its own step accent, not copy-pasted',
      (tester) async {
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
              matching: find.byWidgetPredicate((widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border != null),
            )
            .first,
      );
      final border = (container.decoration as BoxDecoration).border as Border;
      return border.top.color;
    }

    expect(borderColorFor('Character'), StoryTheme.accentCharacter);
    expect(borderColorFor('Mood'), StoryTheme.accentMood);
    expect(borderColorFor('Setting'), StoryTheme.accentSetting);
  });
}
