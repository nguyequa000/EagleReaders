import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/hero_controls.dart';
import 'package:storysprout/screens/story/hero_preview.dart';
import 'package:storysprout/screens/story_hero_screen.dart';

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
    await tester.pumpWidget(MaterialApp(
      home: StoryHeroScreen(hero: hero, onNext: onNext, onBack: onBack),
    ));
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
      final found = await pageToward(Icons.chevron_right) ||
          await pageToward(Icons.chevron_left);
      expect(found, isTrue,
          reason: '"$label" never appeared after paging the strip both ways');
    }

    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('opens on the Avatar row with a hero already drawn', (
    tester,
  ) async {
    await pumpBuilder(tester);

    expect(find.byType(HeroPreview), findsOneWidget);
    expect(find.text('PICK YOUR HERO'), findsOneWidget);
    for (final label in const <String>[
      'Avatar',
      'Hair',
      'Hat',
      'Outfit',
      'Pet',
    ]) {
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

    expect(delivered, isNotNull,
        reason: 'there is no unfinished hero to gate on');
  });

  testWidgets('switching feature changes both the row label and the strip',
      (tester) async {
    await pumpBuilder(tester);

    await tester.tap(find.text('Outfit'));
    await tester.pump();

    expect(find.text('PICK AN OUTFIT'), findsOneWidget);
    final strip = tester.widget<HeroOptionStrip>(find.byType(HeroOptionStrip));
    expect(strip.feature, HeroFeature.outfit);
  });

  testWidgets('choosing an option updates the hero behind the preview', (
    tester,
  ) async {
    await pumpBuilder(tester);
    await tester.tap(find.text('Outfit'));
    await tester.pump();

    final option = HeroCatalog.optionsFor(HeroFeature.outfit)
        .firstWhere((o) => o.value == 'hoodie');
    await tapOption(tester, option.label);

    expect(heroOf(tester).outfitVariant, 'hoodie');
  });

  testWidgets('the colour row appears only where something can be tinted', (
    tester,
  ) async {
    await pumpBuilder(tester);

    // Avatar is the opening row and has no wheel: the row is itself the
    // skin-tone choice, shown as faces rather than dots.
    expect(find.byType(HeroColorRow), findsNothing);

    await tester.tap(find.text('Hair'));
    await tester.pump();
    expect(find.byType(HeroColorRow), findsOneWidget);
    expect(find.text('HAIR COLOUR'), findsOneWidget);

    await tester.tap(find.text('Pet'));
    await tester.pump();

    // A pet is a bundled picture, not a tinted layer, so it has no colours.
    expect(find.byType(HeroColorRow), findsNothing);
  });

  testWidgets('a hat hides the hair and taking it off brings the hair back', (
    tester,
  ) async {
    await pumpBuilder(
      tester,
      hero: const HeroConfig().withOption(HeroFeature.hair, 'bigHair'),
    );

    await tester.tap(find.text('Hat'));
    await tester.pump();
    await tapOption(tester, HeroCatalog.humanize('turban'));
    expect(heroOf(tester).effectiveTop, 'turban');

    await tapOption(tester, 'None');

    final hero = heroOf(tester);
    expect(hero.hatVariant, isNull);
    expect(hero.effectiveTop, 'bigHair',
        reason: 'removing a hat must not leave the child bald');
  });

  testWidgets('Surprise me dresses the bare hero', (tester) async {
    await pumpBuilder(tester);
    expect(heroOf(tester).isBare, isTrue, reason: 'starts as a bare base');

    await tester.tap(find.text('Surprise me!'));
    await tester.pump();

    final rolled = heroOf(tester);
    expect(rolled.isBare, isFalse);
    expect(rolled.hairVariant, isNotNull);
    expect(rolled.outfitVariant, isNotNull);
  });

  testWidgets('the hero survives being handed on to the next step', (
    tester,
  ) async {
    HeroConfig? delivered;
    await pumpBuilder(tester, onNext: (hero) => delivered = hero);

    await tester.tap(find.text('Outfit'));
    await tester.pump();
    await tapOption(tester, HeroCatalog.humanize('hoodie'));
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(delivered?.outfitVariant, 'hoodie');
  });

  testWidgets('an incoming hero is restored rather than reset', (tester) async {
    await pumpBuilder(
      tester,
      hero: const HeroConfig(skinTone: '#614335')
          .withOption(HeroFeature.outfit, 'overall'),
    );

    final hero = heroOf(tester);
    expect(hero.skinTone, '#614335');
    expect(hero.outfitVariant, 'overall');
  });

  testWidgets('back leaves the flow', (tester) async {
    var backs = 0;
    await pumpBuilder(tester, onBack: () => backs++);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });
}
