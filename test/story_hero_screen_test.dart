import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/hero_controls.dart';
import 'package:storysprout/screens/story/hero_preview.dart';
import 'package:storysprout/screens/story_hero_screen.dart';

/// Named from the catalogue rather than hard-coded, so renaming or retiring
/// an option shows up as one failure here instead of a dozen cryptic ones.
final String aHero = HeroCatalog.heroes
    .firstWhere((o) => o.label == 'Robot')
    .value!;
final String aPose = HeroCatalog.poses
    .firstWhere((o) => o.label == 'Jumping')
    .value!;

void main() {
  Future<void> pumpBuilder(
    WidgetTester tester, {
    HeroConfig hero = const HeroConfig(),
    void Function(HeroConfig)? onNext,
    VoidCallback? onBack,
  }) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StoryHeroScreen(hero: hero, onNext: onNext, onBack: onBack),
      ),
    );
    await tester.pump();
  }

  HeroConfig heroOf(WidgetTester tester) =>
      tester.widget<HeroPreview>(find.byType(HeroPreview)).hero;

  /// Taps an option, paging the strip with its own arrows until the tile exists.
  ///
  /// The strip builds lazily, so a tile far enough away is not merely
  /// off-screen — it is not built at all, and ensureVisible has nothing to work
  /// with. Searching both directions matters: "None" sits at index 0, so after
  /// paging forward to reach a hat it can only be found by going back.
  /// Driving the real arrow controls doubles as cover for them.
  Future<void> tapOption(WidgetTester tester, String label) async {
    final target = find.text(label);

    Future<bool> pageToward(IconData arrow) async {
      for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
        await tester.tap(find.byIcon(arrow));
        await tester.pump();
      }
      return target.evaluate().isNotEmpty;
    }

    if (target.evaluate().isEmpty) {
      final found =
          await pageToward(Icons.chevron_right) ||
          await pageToward(Icons.chevron_left);
      expect(
        found,
        isTrue,
        reason: '"$label" never appeared after paging the strip both ways',
      );
    }

    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('opens on the Hero row with a hero already drawn', (
    tester,
  ) async {
    await pumpBuilder(tester);

    expect(find.byType(HeroPreview), findsOneWidget);
    expect(find.text('PICK YOUR HERO'), findsOneWidget);
    for (final label in const <String>['Hero', 'Pose', 'Pet']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Next is live immediately — a seeded hero is already complete', (
    tester,
  ) async {
    HeroConfig? delivered;
    await pumpBuilder(tester, onNext: (hero) => delivered = hero);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(
      delivered,
      isNotNull,
      reason: 'there is no unfinished hero to gate on',
    );
  });

  testWidgets('switching feature changes both the row label and the strip', (
    tester,
  ) async {
    await pumpBuilder(tester);

    await tester.tap(find.text('Pose'));
    await tester.pump();

    expect(find.text('WHAT ARE THEY DOING?'), findsOneWidget);
    final strip = tester.widget<HeroOptionStrip>(find.byType(HeroOptionStrip));
    expect(strip.feature, HeroFeature.pose);
  });

  testWidgets('choosing an option updates the hero behind the preview', (
    tester,
  ) async {
    await pumpBuilder(tester);
    await tester.tap(find.text('Pose'));
    await tester.pump();

    await tapOption(tester, 'Jumping');

    expect(heroOf(tester).pose, aPose);
    expect(heroOf(tester).assetPath, contains(aPose));
  });

  testWidgets('the outfit wheel sits on the hero row only', (tester) async {
    await pumpBuilder(tester);

    expect(find.byType(HeroColorRow), findsOneWidget);
    expect(find.text('OUTFIT COLOUR'), findsOneWidget);

    for (final row in <String>['Pose', 'Pet']) {
      await tester.tap(find.text(row));
      await tester.pump();
      expect(find.byType(HeroColorRow), findsNothing, reason: row);
    }
  });

  testWidgets('picking an outfit colour redresses the hero', (tester) async {
    await pumpBuilder(tester);
    final before = heroOf(tester).assetPath;

    final swatches = find.descendant(
      of: find.byType(HeroColorRow),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(swatches.at(3));
    await tester.pump();

    expect(heroOf(tester).outfitColor, isNotNull);
    expect(heroOf(tester).assetPath, isNot(before));
  });

  testWidgets('a pet can be taken off again, a hero cannot', (tester) async {
    await pumpBuilder(tester);

    await tester.tap(find.text('Pet'));
    await tester.pump();
    await tapOption(tester, 'Pip');
    expect(heroOf(tester).petAsset, isNotNull);

    await tapOption(tester, 'None');
    expect(heroOf(tester).petAsset, isNull);

    // The hero row has no None to tap — there would be nothing left to draw.
    await tester.tap(find.text('Hero'));
    await tester.pump();
    expect(
      HeroCatalog.optionsFor(HeroFeature.hero).map((o) => o.value),
      everyElement(isNotNull),
    );
  });

  testWidgets('Surprise me rolls a whole hero', (tester) async {
    await pumpBuilder(tester);
    expect(heroOf(tester).isBare, isTrue, reason: 'starts unbuilt');

    await tester.tap(find.text('Surprise me!'));
    await tester.pump();

    final rolled = heroOf(tester);
    expect(rolled.isBare, isFalse);
    expect(rolled.character, isNotNull);
    expect(rolled.pose, isNotNull);
  });

  testWidgets('the hero survives being handed on to the next step', (
    tester,
  ) async {
    HeroConfig? delivered;
    await pumpBuilder(tester, onNext: (hero) => delivered = hero);

    await tester.tap(find.text('Pose'));
    await tester.pump();
    await tapOption(tester, 'Jumping');
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(delivered?.pose, aPose);
  });

  testWidgets('an incoming hero is restored rather than reset', (tester) async {
    await pumpBuilder(
      tester,
      hero: const HeroConfig()
          .withOption(HeroFeature.hero, aHero)
          .withOption(HeroFeature.pose, aPose),
    );

    final hero = heroOf(tester);
    expect(hero.character, aHero);
    expect(hero.pose, aPose);
  });

  testWidgets('back leaves the flow', (tester) async {
    var backs = 0;
    await pumpBuilder(tester, onBack: () => backs++);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });
}
