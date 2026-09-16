import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';

/// Regression cover for the bugs found by running the app in Chrome.
///
/// Two of them were invisible to the VM test suite, which is the point of this
/// file: it pins the specific values and behaviours that differ between the VM
/// and the web, where this app is actually previewed.
void main() {
  group('The bare base', () {
    String slots(String svg) => RegExp(r'id="([a-zA-Z]+)-([A-Za-z0-9]+)-')
        .allMatches(svg)
        .map((m) => '${m.group(1)}=${m.group(2)}')
        .join(', ');

    test('a new hero wears nothing nobody chose', () {
      const bare = HeroConfig();
      final svg = bare.toSvg();

      expect(bare.isBare, isTrue);
      expect(svg, isNot(contains('id="top-')), reason: 'no hair and no hat');
      expect(svg, isNot(contains('id="facialHair-')), reason: 'no beard');
      expect(svg, isNot(contains('id="accessories-')), reason: 'no glasses');
      expect(svg, isNot(contains('id="clothesGraphic-')),
          reason: 'no slogan on the shirt');
    });

    test('the base face is neutral, not an expression', () {
      final svg = const HeroConfig().toSvg();
      expect(svg, contains('id="eyes-default-'));
      expect(svg, contains('id="mouth-default-'));
      expect(svg, contains('id="eyebrows-default-'));
    });

    test('a bare hero still renders a whole figure', () {
      final svg = const HeroConfig().toSvg();
      expect(svg, startsWith('<svg'));
      // Clothes carry no probability in the catalogue, so the figure is
      // dressed even when nothing was chosen. Anything else is a bare torso.
      expect(svg, contains('id="clothes-shirtCrewNeck-'),
          reason: slots(svg));
    });

    test('adding a feature adds exactly that feature', () {
      final withHair =
          const HeroConfig().withOption(HeroFeature.hair, 'bigHair');
      expect(withHair.toSvg(), contains('id="top-bigHair-'));
      expect(withHair.isBare, isFalse);
      // and nothing else arrived alongside it
      expect(withHair.toSvg(), isNot(contains('id="facialHair-')));
    });

    test('every base differs only in skin tone', () {
      final tones = HeroCatalog.skinTones;
      expect(tones, isNotEmpty);
      for (final tone in tones) {
        final svg = const HeroConfig().withOption(HeroFeature.avatar, tone).toSvg();
        expect(svg, contains(tone));
        expect(svg, isNot(contains('id="top-')));
      }
    });

    test('the Avatar row offers the bases and no separate colour wheel', () {
      final options = HeroCatalog.optionsFor(HeroFeature.avatar);
      expect(options, hasLength(HeroCatalog.skinTones.length));
      expect(options.map((o) => o.value), HeroCatalog.skinTones);
      // Two controls for one value would be two ways to change one thing.
      expect(HeroCatalog.colorsFor(HeroFeature.avatar), isEmpty);
    });
  });

  group('Randomize', () {
    test('does not throw, however many times it is tapped', () {
      var hero = const HeroConfig();
      for (var i = 0; i < 200; i++) {
        hero = hero.randomized();
      }
      expect(hero.toSvg(), startsWith('<svg'));
    });

    test('actually produces different heroes', () {
      final looks = <String>{};
      var hero = const HeroConfig();
      for (var i = 0; i < 50; i++) {
        hero = hero.randomized();
        looks.add(hero.toSvg());
      }
      // The reported symptom was "only one character to choose from" — the
      // roll threw before it could change anything, so the hero never moved.
      expect(looks.length, greaterThan(20),
          reason: 'a roll that repeats itself is not a roll');
    });

    test('a rolled hero is dressed, not bare', () {
      final rolled = const HeroConfig().randomized(Random(11));
      expect(rolled.isBare, isFalse);
      expect(rolled.hairVariant, isNotNull);
      expect(rolled.outfitVariant, isNotNull);
    });

    test('every roll still renders', () {
      var hero = const HeroConfig();
      for (var i = 0; i < 50; i++) {
        hero = hero.randomized();
        expect(hero.toSvg(size: 220), startsWith('<svg'));
      }
    });
  });

  group('Expression, driven by mood', () {
    String? mouthOf(HeroConfig hero, String? mood) =>
        RegExp(r'id="mouth-([a-zA-Z]+)-')
            .firstMatch(hero.toSvgForMood(mood))
            ?.group(1);
    String? eyesOf(HeroConfig hero, String? mood) =>
        RegExp(r'id="eyes-([a-zA-Z]+)-')
            .firstMatch(hero.toSvgForMood(mood))
            ?.group(1);

    test('changes the whole face, not just the eyes', () {
      const hero = HeroConfig();
      final funny = hero.toSvgForMood('Funny');
      final spooky = hero.toSvgForMood('Spooky');

      expect(mouthOf(hero, 'Funny'), isNotNull);
      expect(mouthOf(hero, 'Funny'), isNot(mouthOf(hero, 'Spooky')),
          reason: 'the mouth was stuck open the same way on every face');
      expect(eyesOf(hero, 'Funny'), isNot(eyesOf(hero, 'Spooky')));
      expect(funny, isNot(spooky));
    });

    test('every mood maps to a distinct face', () {
      const hero = HeroConfig();
      final faces = <String>{};
      for (final mood in <String>['Funny', 'Adventurous', 'Spooky', 'Calm']) {
        faces.add('${eyesOf(hero, mood)}/${mouthOf(hero, mood)}');
      }
      expect(faces, hasLength(4),
          reason: 'two moods wearing the same face makes the choice look inert');
    });

    test('each expression renders the eyes and mouth it names', () {
      for (final expression in HeroCatalog.expressions) {
        final svg = const HeroConfig().toSvg(expression: expression);
        expect(RegExp(r'id="eyes-([a-zA-Z]+)-').firstMatch(svg)?.group(1),
            expression.eyes,
            reason: expression.label);
        expect(RegExp(r'id="mouth-([a-zA-Z]+)-').firstMatch(svg)?.group(1),
            expression.mouth,
            reason: expression.label);
      }
    });

    test('an unchosen or unknown mood still gets a face', () {
      expect(HeroCatalog.expressionForMood(null).id, 'happy');
      expect(HeroCatalog.expressionForMood('nonsense').id, 'happy');
      // Matching is case-insensitive: the catalogue labels are capitalised but
      // nothing guarantees a caller passes them that way.
      expect(HeroCatalog.expressionForMood('spooky').id,
          HeroCatalog.expressionForMood('Spooky').id);
    });

    test('the hero carries a neutral face until a mood supplies one', () {
      // Neutral is pinned rather than left unset. Unset means the engine picks
      // one from the seed, which is how heroes ended up with a random
      // permanently-open mouth.
      final bare = const HeroConfig().toAvatarOptions();
      expect(bare['eyesVariant'], <String>['default']);
      expect(bare['mouthVariant'], <String>['default']);

      final spooky = const HeroConfig().toAvatarOptions(
        expression: HeroCatalog.expressionForMood('Spooky'),
      );
      expect(spooky['eyesVariant'], isNot(<String>['default']));
      expect(spooky['mouthVariant'], isNot(<String>['default']));
    });
  });

  group('Avatar row', () {
    test('picking a base keeps deliberate choices', () {
      final tone = HeroCatalog.skinTones.last;
      final hero = const HeroConfig()
          .withOption(HeroFeature.outfit, 'hoodie')
          .withOption(HeroFeature.avatar, tone);

      expect(hero.skinTone, tone);
      expect(hero.outfitVariant, 'hoodie',
          reason: 'a chosen outfit was a decision, not a default');
      expect(hero.selectedValue(HeroFeature.avatar), tone);
    });
  });
}
