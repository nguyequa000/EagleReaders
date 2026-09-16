import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';

void main() {
  group('catalogue', () {
    test('every feature row has options', () {
      for (final feature in HeroFeature.values) {
        expect(HeroCatalog.optionsFor(feature), isNotEmpty,
            reason: HeroCatalog.labelFor(feature));
      }
    });

    test('hair and hat partition the same top slot without overlapping', () {
      final hair = HeroCatalog.optionsFor(HeroFeature.hair)
          .map((o) => o.value)
          .whereType<String>()
          .toSet();
      final hats = HeroCatalog.optionsFor(HeroFeature.hat)
          .map((o) => o.value)
          .whereType<String>()
          .toSet();

      expect(hair.intersection(hats), isEmpty);
      // Together they must account for every top variant, or a variant would
      // exist in the catalogue that no row can ever reach.
      expect(hair.length + hats.length, 34);
      expect(hats, contains('turban'));
      expect(hair, contains('bigHair'));
    });

    test('rows that can be empty offer a None, and rows that cannot do not', () {
      for (final feature in <HeroFeature>[HeroFeature.hat, HeroFeature.pet]) {
        expect(HeroCatalog.optionsFor(feature).first.value, isNull,
            reason: '${HeroCatalog.labelFor(feature)} must be removable');
      }
      for (final feature in <HeroFeature>[
        HeroFeature.avatar,
        HeroFeature.hair,
        HeroFeature.outfit,
      ]) {
        expect(
          HeroCatalog.optionsFor(feature).map((o) => o.value),
          everyElement(isNotNull),
          reason: 'a hero always has a ${HeroCatalog.labelFor(feature)}',
        );
      }
    });

    test('only the rows that tint something carry a colour wheel', () {
      // Avatar has none because the row itself is the skin-tone choice, shown
      // as faces; Pet has none because a pet is a bundled picture.
      const without = <HeroFeature>[HeroFeature.avatar, HeroFeature.pet];
      for (final feature in HeroFeature.values) {
        final colors = HeroCatalog.colorsFor(feature);
        if (without.contains(feature)) {
          expect(colors, isEmpty, reason: HeroCatalog.labelFor(feature));
        } else {
          expect(colors, isNotEmpty, reason: HeroCatalog.labelFor(feature));
          for (final swatch in colors) {
            expect(swatch, matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
          }
        }
      }
    });

    test('humanize turns catalogue ids into readable labels', () {
      expect(HeroCatalog.humanize('shirtCrewNeck'), 'Shirt Crew Neck');
      expect(HeroCatalog.humanize('bigHair'), 'Big Hair');
      expect(HeroCatalog.humanize('winterHat02'), 'Winter Hat 02');
      expect(HeroCatalog.humanize('turban'), 'Turban');
    });

    test('every pet asset path is one this app bundles', () {
      for (final asset in HeroCatalog.petAssets) {
        expect(asset, startsWith('assets/story/pets/'));
        expect(asset, endsWith('.png'));
      }
    });
  });

  group('config', () {
    test('a bare hero renders a bare person', () {
      const hero = HeroConfig();
      final svg = hero.toSvg();
      expect(svg, startsWith('<svg'));
      // Nothing is pinned, so the seed supplies everything.
      // The base pins its own bareness rather than leaving it to chance.
      expect(hero.toAvatarOptions()['topProbability'], 0);
      expect(hero.toAvatarOptions()['facialHairProbability'], 0);
    });

    test('choosing an option pins exactly that one', () {
      final hero = const HeroConfig().withOption(HeroFeature.outfit, 'hoodie');
      expect(hero.outfitVariant, 'hoodie');
      expect(hero.toAvatarOptions()['clothesVariant'], <String>['hoodie']);
      expect(hero.toAvatarOptions().containsKey('topVariant'), isFalse);
    });

    test('a hat hides the hair but does not erase it', () {
      final hero = const HeroConfig()
          .withOption(HeroFeature.hair, 'bigHair')
          .withOption(HeroFeature.hat, 'turban');

      expect(hero.effectiveTop, 'turban');
      expect(hero.hairVariant, 'bigHair',
          reason: 'the hair has to survive so taking the hat off restores it');

      final bareheaded = hero.withOption(HeroFeature.hat, null);
      expect(bareheaded.hatVariant, isNull);
      expect(bareheaded.effectiveTop, 'bigHair');
    });

    test('hair colour and hat colour never both apply', () {
      final hatted = const HeroConfig()
          .withOption(HeroFeature.hair, 'bigHair')
          .withOption(HeroFeature.hat, 'turban')
          .withColor(HeroFeature.hair, '#4a312c')
          .withColor(HeroFeature.hat, '#2a8c82');

      final options = hatted.toAvatarOptions();
      expect(options['hatColor'], <String>['#2a8c82']);
      expect(options.containsKey('hairColor'), isFalse,
          reason: 'tinting hair nobody can see is a silent no-op');

      final bare = hatted.withOption(HeroFeature.hat, null).toAvatarOptions();
      expect(bare['hairColor'], <String>['#4a312c']);
      expect(bare.containsKey('hatColor'), isFalse);
    });

    test('a chosen colour reaches the rendered SVG', () {
      final hero = const HeroConfig()
          .withOption(HeroFeature.outfit, 'hoodie')
          .withColor(HeroFeature.outfit, '#2a8c82');
      expect(hero.toSvg(), contains('#2a8c82'));
    });

    test('selectedValue reads back what was set, per row', () {
      var hero = const HeroConfig();
      for (final feature in HeroFeature.values) {
        final option = HeroCatalog.optionsFor(feature)
            .firstWhere((o) => o.value != null);
        hero = hero.withOption(feature, option.value);
        expect(hero.selectedValue(feature), option.value,
            reason: HeroCatalog.labelFor(feature));
      }
    });

    test('randomize changes the look, keeps the name and the pet', () {
      final hero = const HeroConfig(name: 'Sparkle')
          .withOption(HeroFeature.pet, 'assets/story/pets/panda.png');
      final rolled = hero.randomized(Random(7));

      expect(rolled.toSvg(), isNot(hero.toSvg()));
      expect(rolled.name, 'Sparkle', reason: 'they worked on the name');
      expect(rolled.petAsset, hero.petAsset,
          reason: 'the pet is a companion, not part of the dice roll');
      expect(rolled.toSvg(), isNot(hero.toSvg()));
    });

    test('randomize replaces pinned features rather than keeping them', () {
      final hero = const HeroConfig().withOption(HeroFeature.outfit, 'hoodie');
      final rolled = hero.randomized(Random(3));
      expect(rolled.outfitVariant, isNotNull,
          reason: 'a roll dresses the hero rather than stripping them');
      // Nothing is left to chance any more: the roll writes real choices.
      expect(rolled.hairVariant, isNotNull);
      expect(rolled.skinTone, isNotNull);
    });

    test('identical choices always give an identical hero', () {
      final a = const HeroConfig()
          .withOption(HeroFeature.hair, 'bigHair')
          .withColor(HeroFeature.hair, '#4a312c');
      final b = const HeroConfig()
          .withOption(HeroFeature.hair, 'bigHair')
          .withColor(HeroFeature.hair, '#4a312c');
      expect(a.toSvg(), b.toSvg());
    });
  });
}
