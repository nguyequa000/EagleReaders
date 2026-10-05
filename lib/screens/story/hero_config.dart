import 'dart:math';

import 'package:flutter/foundation.dart';

import 'hero_catalog.dart';

/// Everything a child chose about their hero.
///
/// Three choices, stored as plain strings so a finished hero can be written
/// straight to Firestore when story saving lands. Unchosen fields fall back to
/// the first option rather than to nothing, so a hero always draws.
@immutable
class HeroConfig {
  /// Which of the six characters, as a catalogue slug.
  final String? character;

  /// What they are doing.
  final String? pose;

  /// The outfit colour, as one of [HeroCatalog.outfitColors]' keys.
  ///
  /// Null draws the character in the colours the pack drew them in, which is
  /// what an unbuilt hero starts as.
  final String? outfitColor;

  /// Bundled Kenney asset path, or null for no pet.
  final String? petAsset;

  /// What the child typed on screen 4. Null until they name them.
  final String? name;

  const HeroConfig({
    this.character,
    this.pose,
    this.outfitColor,
    this.petAsset,
    this.name,
  });

  String get effectiveCharacter => character ?? HeroCatalog.heroes.first.value!;

  String get effectivePose => pose ?? HeroCatalog.poses.first.value!;

  /// The picture this hero draws.
  ///
  /// One file, not a composition. That is the whole reason this engine has no
  /// library, no colour tokens and no load step: a hero is a picture, and a
  /// picture cannot be half-assembled, mis-tinted, or served stale from a
  /// cache that outlived a hot reload.
  String get assetPath =>
      HeroCatalog.assetFor(effectiveCharacter, effectivePose, outfitColor);

  /// True while nothing has been chosen.
  bool get isBare =>
      character == null &&
      pose == null &&
      outfitColor == null &&
      petAsset == null;

  /// The currently chosen option for a row, so the strip can mark it.
  String? selectedValue(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.hero:
        return character;
      case HeroFeature.pose:
        return pose;
      case HeroFeature.pet:
        return petAsset;
    }
  }

  /// The chosen swatch for a row, so the wheel can mark it.
  String? selectedColor(HeroFeature feature) =>
      feature == HeroFeature.hero ? outfitColor : null;

  /// Sets one row's option. [value] of null clears it, which is how a pet is
  /// taken off.
  HeroConfig withOption(HeroFeature feature, String? value) {
    switch (feature) {
      case HeroFeature.hero:
        // A hero is never "none" — there would be nothing to draw.
        return value == null ? this : copyWith(character: value);
      case HeroFeature.pose:
        return value == null ? this : copyWith(pose: value);
      case HeroFeature.pet:
        return copyWith(petAsset: value, clearPet: value == null);
    }
  }

  /// Sets the outfit colour. Only the hero row has a wheel.
  HeroConfig withColor(HeroFeature feature, String value) =>
      feature == HeroFeature.hero ? copyWith(outfitColor: value) : this;

  /// A random hero.
  ///
  /// Every draw is a list index. Note the absence of any `nextInt` on a count
  /// that could be zero — an empty list there throws, which is what broke
  /// Randomize twice before.
  ///
  /// Keeps the name and the pet: the name is work the child did, and the pet
  /// is a companion rather than part of the hero.
  HeroConfig randomized([Random? random]) {
    final rng = random ?? Random();
    String pick(List<HeroOption> from) => from[rng.nextInt(from.length)].value!;

    final swatches = HeroCatalog.outfitColors.keys.toList();
    return HeroConfig(
      character: pick(HeroCatalog.heroes),
      pose: pick(HeroCatalog.poses),
      outfitColor: swatches[rng.nextInt(swatches.length)],
      petAsset: petAsset,
      name: name,
    );
  }

  HeroConfig copyWith({
    String? character,
    String? pose,
    String? outfitColor,
    String? petAsset,
    String? name,
    bool clearPet = false,
  }) {
    return HeroConfig(
      character: character ?? this.character,
      pose: pose ?? this.pose,
      outfitColor: outfitColor ?? this.outfitColor,
      petAsset: clearPet ? null : (petAsset ?? this.petAsset),
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HeroConfig &&
      other.character == character &&
      other.pose == pose &&
      other.outfitColor == outfitColor &&
      other.petAsset == petAsset &&
      other.name == name;

  @override
  int get hashCode => Object.hash(character, pose, outfitColor, petAsset, name);
}
