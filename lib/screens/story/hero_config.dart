import 'dart:math';

import 'package:dicebear_core/dicebear_core.dart';
import 'package:flutter/foundation.dart';

import 'hero_catalog.dart';

/// Everything a child chose about their hero.
///
/// Every visible feature is stored explicitly. There is no seed: a new hero is
/// a **bare base** — a plain figure with a skin tone, no hair, no hat, no
/// facial hair, no glasses and a neutral face — and everything beyond that is
/// something the child added on purpose.
///
/// That is deliberate, and a change from seeding the unchosen parts. A seeded
/// hero arrived already wearing a hairstyle, an outfit and an expression nobody
/// picked, which made the builder feel like editing a stranger rather than
/// building someone.
///
/// Stored as plain strings, so a finished hero can be written straight to
/// Firestore when story saving lands.
@immutable
class HeroConfig {
  /// The base figure's skin tone, as `#rrggbb`.
  ///
  /// Null renders the catalogue's first tone, so a hero always draws.
  final String? skinTone;

  final String? hairVariant;

  /// Null when the hero is bare-headed.
  ///
  /// Kept separate from [hairVariant] even though both write to the same `top`
  /// slot, so taking a hat off restores the hair underneath rather than
  /// leaving the child bald unexpectedly.
  final String? hatVariant;

  final String? outfitVariant;

  /// Bundled Kenney asset path, or null for no pet.
  final String? petAsset;

  final String? hairColor;
  final String? hatColor;
  final String? clothesColor;

  /// What the child typed on screen 4. Null until they name them.
  final String? name;

  const HeroConfig({
    this.skinTone,
    this.hairVariant,
    this.hatVariant,
    this.outfitVariant,
    this.petAsset,
    this.hairColor,
    this.hatColor,
    this.clothesColor,
    this.name,
  });

  /// Which `top` variant renders: a hat covers the hair beneath it.
  String? get effectiveTop => hatVariant ?? hairVariant;

  /// The skin tone actually drawn.
  String get effectiveSkinTone => skinTone ?? HeroCatalog.skinTones.first;

  /// True while nothing has been added to the base figure.
  bool get isBare =>
      hairVariant == null &&
      hatVariant == null &&
      outfitVariant == null &&
      petAsset == null;

  /// The currently chosen option for a row, so the strip can mark it.
  String? selectedValue(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.avatar:
        return skinTone;
      case HeroFeature.hair:
        return hairVariant;
      case HeroFeature.hat:
        return hatVariant;
      case HeroFeature.outfit:
        return outfitVariant;
      case HeroFeature.pet:
        return petAsset;
    }
  }

  String? selectedColor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.avatar:
      case HeroFeature.pet:
        return null;
      case HeroFeature.hair:
        return hairColor;
      case HeroFeature.hat:
        return hatColor;
      case HeroFeature.outfit:
        return clothesColor;
    }
  }

  /// Sets one row's option. [value] of null clears it, which is how a hat or a
  /// pet is taken off.
  HeroConfig withOption(HeroFeature feature, String? value) {
    switch (feature) {
      case HeroFeature.avatar:
        // The Avatar row *is* the base figure, so its options are skin tones.
        return value == null ? this : copyWith(skinTone: value);
      case HeroFeature.hair:
        return copyWith(hairVariant: value, clearHair: value == null);
      case HeroFeature.hat:
        return copyWith(hatVariant: value, clearHat: value == null);
      case HeroFeature.outfit:
        return copyWith(outfitVariant: value, clearOutfit: value == null);
      case HeroFeature.pet:
        return copyWith(petAsset: value, clearPet: value == null);
    }
  }

  HeroConfig withColor(HeroFeature feature, String value) {
    switch (feature) {
      case HeroFeature.avatar:
      case HeroFeature.pet:
        return this;
      case HeroFeature.hair:
        return copyWith(hairColor: value);
      case HeroFeature.hat:
        return copyWith(hatColor: value);
      case HeroFeature.outfit:
        return copyWith(clothesColor: value);
    }
  }

  /// A random hero.
  ///
  /// Rolls the features themselves rather than a seed. With the base bare and
  /// every visible part explicit there is no seed left for a roll to move, and
  /// rolling the real choices is what the child sees anyway.
  ///
  /// Note the absence of any `nextInt(1 << 32)` here: every draw is a list
  /// index. On the web `1 << 32` is 0 and `nextInt(0)` throws, which is what
  /// broke the previous seed-based Randomize in Chrome.
  ///
  /// Keeps the name and the pet — the name is work they did, and the pet is a
  /// companion rather than part of the hero's look.
  HeroConfig randomized([Random? random]) {
    final rng = random ?? Random();

    String? pick(HeroFeature feature) {
      final values = HeroCatalog.optionsFor(feature)
          .map((option) => option.value)
          .whereType<String>()
          .toList();
      if (values.isEmpty) return null;
      return values[rng.nextInt(values.length)];
    }

    String pickColor(HeroFeature feature) {
      final swatches = HeroCatalog.colorsFor(feature);
      return swatches[rng.nextInt(swatches.length)];
    }

    // A hat only some of the time: always hatting a random hero hides the
    // hairstyle the same roll just chose.
    final wearsHat = rng.nextInt(4) == 0;

    return HeroConfig(
      skinTone: HeroCatalog.skinTones[rng.nextInt(HeroCatalog.skinTones.length)],
      hairVariant: pick(HeroFeature.hair),
      hatVariant: wearsHat ? pick(HeroFeature.hat) : null,
      outfitVariant: pick(HeroFeature.outfit),
      hairColor: pickColor(HeroFeature.hair),
      hatColor: wearsHat ? pickColor(HeroFeature.hat) : null,
      clothesColor: pickColor(HeroFeature.outfit),
      petAsset: petAsset,
      name: name,
    );
  }

  /// The option map handed to the avatar engine.
  ///
  /// Everything visible is pinned, so the render is fully determined by the
  /// child's choices. The seed is a constant: with nothing left unpinned, it
  /// has nothing to decide.
  Map<String, Object?> toAvatarOptions({
    int size = 220,
    HeroExpression? expression,
  }) {
    final options = <String, Object?>{
      'seed': 'base',
      'size': size,
      'skinColor': <String>[effectiveSkinTone],

      // The bare base. None of these has a row in the builder, and Avataaars
      // would otherwise give one hero in ten a beard or a pair of glasses that
      // nobody asked for and no control can remove.
      'facialHairProbability': 0,
      'accessoriesProbability': 0,
      'clothesGraphicProbability': 0,

      // A neutral face. The story's mood replaces this; on its own the base
      // wears no expression.
      'eyebrowsVariant': const <String>['default'],
      'eyesVariant': <String>[expression?.eyes ?? 'default'],
      'mouthVariant': <String>[expression?.mouth ?? 'default'],

      // Clothes carry no probability in the catalogue, so a figure always
      // wears something. A plain crew neck is the quietest thing available.
      'clothesVariant': <String>[outfitVariant ?? 'shirtCrewNeck'],
    };

    final top = effectiveTop;
    if (top == null) {
      // Neither hair nor hat chosen: a bare head, not a random hairstyle.
      options['topProbability'] = 0;
    } else {
      options['topVariant'] = <String>[top];
    }

    if (clothesColor != null) options['clothesColor'] = <String>[clothesColor!];

    // Hair colour is meaningless under a hat, and hat colour is meaningless
    // without one. Sending both lets whichever is irrelevant quietly tint
    // something the child cannot see.
    if (hatVariant != null) {
      if (hatColor != null) options['hatColor'] = <String>[hatColor!];
    } else if (hairColor != null) {
      options['hairColor'] = <String>[hairColor!];
    }

    return options;
  }

  /// Renders this hero to an SVG string, entirely offline.
  ///
  /// Pass [expression] to give them the face matching the story's mood.
  String toSvg({int size = 220, HeroExpression? expression}) => Avatar(
        HeroCatalog.style,
        toAvatarOptions(size: size, expression: expression),
      ).svg;

  /// The hero wearing the face that matches [mood].
  String toSvgForMood(String? mood, {int size = 220}) =>
      toSvg(size: size, expression: HeroCatalog.expressionForMood(mood));

  HeroConfig copyWith({
    String? skinTone,
    String? hairVariant,
    String? hatVariant,
    String? outfitVariant,
    String? petAsset,
    String? hairColor,
    String? hatColor,
    String? clothesColor,
    String? name,
    bool clearHair = false,
    bool clearHat = false,
    bool clearOutfit = false,
    bool clearPet = false,
  }) {
    return HeroConfig(
      skinTone: skinTone ?? this.skinTone,
      hairVariant: clearHair ? null : (hairVariant ?? this.hairVariant),
      hatVariant: clearHat ? null : (hatVariant ?? this.hatVariant),
      outfitVariant: clearOutfit ? null : (outfitVariant ?? this.outfitVariant),
      petAsset: clearPet ? null : (petAsset ?? this.petAsset),
      hairColor: hairColor ?? this.hairColor,
      hatColor: hatColor ?? this.hatColor,
      clothesColor: clothesColor ?? this.clothesColor,
      name: name ?? this.name,
    );
  }
}
