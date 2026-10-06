import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';

void main() {
  group('catalogue', () {
    test('every feature row has options', () {
      for (final feature in HeroFeature.values) {
        expect(
          HeroCatalog.optionsFor(feature),
          isNotEmpty,
          reason: HeroCatalog.labelFor(feature),
        );
      }
    });

    test('only the pet row can be empty', () {
      // A hero and a pose always draw something; "none" there would leave an
      // empty preview box with no way back.
      expect(HeroCatalog.optionsFor(HeroFeature.pet).first.value, isNull);
      for (final feature in <HeroFeature>[HeroFeature.hero, HeroFeature.pose]) {
        expect(
          HeroCatalog.optionsFor(feature).map((o) => o.value),
          everyElement(isNotNull),
          reason: HeroCatalog.labelFor(feature),
        );
      }
    });

    test('only the hero row carries a colour wheel', () {
      // The colour is what the hero is wearing, so it belongs with who they
      // are rather than with what they are doing or which animal follows them.
      expect(HeroCatalog.colorsFor(HeroFeature.hero), hasLength(5));
      for (final feature in <HeroFeature>[HeroFeature.pose, HeroFeature.pet]) {
        expect(
          HeroCatalog.colorsFor(feature),
          isEmpty,
          reason: HeroCatalog.labelFor(feature),
        );
      }
    });

    test('every swatch names a generated outfit', () {
      // A swatch with no matching picture would select a path that does not
      // exist, and a missing image draws as nothing at all.
      for (final hex in HeroCatalog.colorsFor(HeroFeature.hero)) {
        expect(hex, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
        expect(HeroCatalog.outfitColors[hex], isNotNull, reason: hex);
        expect(
          HeroCatalog.assetFor('explorer', 'idle', hex),
          endsWith('-${HeroCatalog.outfitColors[hex]}.png'),
        );
      }
    });

    test('an outfit colour changes the picture, and clears back', () {
      const bare = HeroConfig();
      final hex = HeroCatalog.colorsFor(HeroFeature.hero).first;
      final dressed = bare.withColor(HeroFeature.hero, hex);

      expect(dressed.assetPath, isNot(bare.assetPath));
      expect(dressed.selectedColor(HeroFeature.hero), hex);
      expect(
        bare.assetPath,
        endsWith('idle.png'),
        reason: 'no colour chosen draws the character as the pack drew them',
      );
    });

    test('option labels are distinct and readable', () {
      for (final feature in HeroFeature.values) {
        final labels = HeroCatalog.optionsFor(
          feature,
        ).map((o) => o.label).toList();
        expect(
          labels.toSet(),
          hasLength(labels.length),
          reason: '${HeroCatalog.labelFor(feature)} repeats a label',
        );
        for (final label in labels) {
          expect(label, isNotEmpty);
          expect(label[0], label[0].toUpperCase());
        }
      }
    });
  });

  group('config', () {
    test('an unbuilt hero still draws', () {
      const bare = HeroConfig();
      expect(bare.isBare, isTrue);
      expect(
        bare.assetPath,
        HeroCatalog.assetFor(
          HeroCatalog.heroes.first.value!,
          HeroCatalog.poses.first.value!,
        ),
        reason: 'the first hero standing still is the opening state',
      );
    });

    test('choosing a hero or a pose changes the picture', () {
      const bare = HeroConfig();
      final other = bare.withOption(
        HeroFeature.hero,
        HeroCatalog.heroes[3].value,
      );
      final posed = bare.withOption(
        HeroFeature.pose,
        HeroCatalog.poses[4].value,
      );

      expect(other.assetPath, isNot(bare.assetPath));
      expect(posed.assetPath, isNot(bare.assetPath));
      expect(posed.assetPath, contains('cheer1'));
    });

    test('a hero cannot be cleared, a pet can', () {
      final built = const HeroConfig()
          .withOption(HeroFeature.hero, HeroCatalog.heroes[2].value)
          .withOption(HeroFeature.pet, HeroCatalog.petAssets.first);

      expect(
        built.withOption(HeroFeature.hero, null).character,
        HeroCatalog.heroes[2].value,
        reason: 'clearing the hero would leave nothing to draw',
      );
      expect(built.withOption(HeroFeature.pet, null).petAsset, isNull);
    });

    test('selectedValue reads back what was set, per row', () {
      var hero = const HeroConfig();
      for (final feature in HeroFeature.values) {
        final option = HeroCatalog.optionsFor(
          feature,
        ).firstWhere((o) => o.value != null);
        hero = hero.withOption(feature, option.value);
        expect(
          hero.selectedValue(feature),
          option.value,
          reason: HeroCatalog.labelFor(feature),
        );
      }
    });

    test('randomize changes the hero, keeps the name and the pet', () {
      final hero = const HeroConfig(
        name: 'Sparkle',
      ).withOption(HeroFeature.pet, 'assets/story/pets/panda.png');
      final rolled = hero.randomized(Random(7));

      expect(rolled.name, 'Sparkle', reason: 'they worked on the name');
      expect(rolled.petAsset, hero.petAsset, reason: 'the pet is a companion');
      expect(rolled.character, isNotNull);
      expect(rolled.pose, isNotNull);
    });

    test('randomize never throws, however many times it is tapped', () {
      // Two separate bugs have crashed Randomize before: an out-of-range seed
      // on the web, and indexing into a palette that had been emptied.
      final rng = Random(3);
      var hero = const HeroConfig();
      for (var i = 0; i < 200; i++) {
        hero = hero.randomized(rng);
        expect(hero.assetPath, startsWith('assets/story/toon/'));
      }
    });

    test('identical choices give an identical hero', () {
      final a = const HeroConfig()
          .withOption(HeroFeature.hero, 'robot')
          .withOption(HeroFeature.pose, 'jump');
      final b = const HeroConfig()
          .withOption(HeroFeature.pose, 'jump')
          .withOption(HeroFeature.hero, 'robot');
      expect(a, b);
      expect(a.assetPath, b.assetPath);
    });
  });

  group('artwork', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('every hero in every pose is actually bundled', () async {
      // 60 pictures, and a missing one shows as an empty preview rather than
      // an error — so the only way to know is to ask for all of them.
      for (final asset in HeroCatalog.allHeroAssets) {
        await expectLater(
          rootBundle.load(asset),
          completes,
          reason: '$asset is offered but not bundled',
        );
      }
    });

    test('every bundled picture holds real image data', () async {
      for (final asset in HeroCatalog.allHeroAssets) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(1000), reason: asset);
      }
    });

    test('every pet is bundled too', () async {
      for (final asset in HeroCatalog.petAssets) {
        await expectLater(rootBundle.load(asset), completes, reason: asset);
      }
    });
  });
}
