import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  Future<void> pumpReader(
    WidgetTester tester, {
    StoryConfig? config,
    VoidCallback? onNextPage,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: StoryReaderScreen(
        config: config ??
            const StoryConfig(
              character: 'Clever Fox',
              mood: 'Spooky',
              setting: 'Ocean',
            ),
        onNextPage: onNextPage,
      ),
    ));
    await tester.pump();
  }

  testWidgets('paints the shared ground colour', (tester) async {
    await pumpReader(tester);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, StoryTheme.ground);
  });

  testWidgets('names the three choices in the preview banner', (tester) async {
    await pumpReader(tester);
    expect(find.textContaining('Clever Fox'), findsWidgets);
    expect(find.textContaining('Spooky'), findsWidgets);
    expect(find.textContaining('Ocean'), findsWidgets);
  });

  testWidgets('story body uses the body face', (tester) async {
    await pumpReader(tester);
    final body = tester.widget<Text>(find.textContaining('Once upon a time'));
    expect(body.style!.fontFamily, 'Nunito');
  });

  testWidgets('banner lines use their own distinct accents', (tester) async {
    await pumpReader(tester);

    final characterValue = tester.widget<Text>(find.text('Clever Fox'));
    final moodValue = tester.widget<Text>(find.text('Spooky'));
    final settingValue = tester.widget<Text>(find.text('Ocean'));

    expect(characterValue.style!.color, StoryTheme.accentCharacter);
    expect(moodValue.style!.color, StoryTheme.accentMood);
    expect(settingValue.style!.color, StoryTheme.accentSetting);

    // Sanity check the three accents are actually distinct colours, so this
    // test can't pass by coincidence if the theme accents were ever collapsed.
    expect(
      <Color>{
        StoryTheme.accentCharacter,
        StoryTheme.accentMood,
        StoryTheme.accentSetting,
      }.length,
      3,
    );
  });

  testWidgets('a config with null fields renders the unknown fallback without throwing', (tester) async {
    await pumpReader(tester, config: const StoryConfig());

    expect(tester.takeException(), isNull);
    expect(find.text('unknown'), findsNWidgets(3));
  });

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
      final popScope = tester
          .widgetList(find.byWidgetPredicate((w) => w is PopScope))
          .single as PopScope;
      expect(popScope.canPop, isFalse);
    });

    testWidgets('allows back when there is no page to turn to', (tester) async {
      await pumpReader(tester);

      final popScope = tester
          .widgetList(find.byWidgetPredicate((w) => w is PopScope))
          .single as PopScope;
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
