import 'package:flutter/foundation.dart';

/// The rows of the hero builder.
///
/// Three, where the earlier avatar engine had five. Kenney's Toon Characters
/// are finished characters rather than a parts bin, so there is no hair, hat
/// or outfit to swap — what a child picks instead is *who* their hero is and
/// *what they are doing*, which is the more legible question at age three.
enum HeroFeature { hero, pose, pet }

/// One selectable option within a feature row.
@immutable
class HeroOption {
  /// The value written into the config, or null for the empty slot the pet
  /// row needs so a child can take one off again.
  final String? value;

  /// What the child reads on the tile.
  final String label;

  const HeroOption({required this.value, required this.label});
}

/// What the builder can offer.
class HeroCatalog {
  const HeroCatalog._();

  static const String _dir = 'assets/story/toon';

  /// The six heroes.
  ///
  /// Labelled by character rather than by the pack's own folder names, which
  /// are gendered ("Female adventurer"). A child picks the one that looks
  /// like their hero; the label should not do that sorting for them.
  static const List<HeroOption> heroes = <HeroOption>[
    HeroOption(value: 'explorer', label: 'Explorer'),
    HeroOption(value: 'scout', label: 'Scout'),
    HeroOption(value: 'friend', label: 'Friend'),
    HeroOption(value: 'pal', label: 'Pal'),
    HeroOption(value: 'robot', label: 'Robot'),
    HeroOption(value: 'monster', label: 'Monster'),
  ];

  /// What the hero is doing.
  ///
  /// Curated from the pack's 45 poses per character. The ones left out are
  /// either fighting (attack, kick, hit, shove), falling, or drawn from
  /// behind — a hero facing away is not a hero a child recognises as theirs.
  static const List<HeroOption> poses = <HeroOption>[
    HeroOption(value: 'idle', label: 'Standing'),
    HeroOption(value: 'walk1', label: 'Walking'),
    HeroOption(value: 'run1', label: 'Running'),
    HeroOption(value: 'jump', label: 'Jumping'),
    HeroOption(value: 'cheer1', label: 'Cheering'),
    HeroOption(value: 'wide', label: 'Arms Wide'),
    HeroOption(value: 'hold', label: 'Holding'),
    HeroOption(value: 'talk', label: 'Talking'),
    HeroOption(value: 'think', label: 'Thinking'),
    HeroOption(value: 'duck', label: 'Hiding'),
  ];

  /// Outfit colours, as the swatch a child taps and the suffix on the
  /// picture it selects.
  ///
  /// These characters are finished drawings with no garment layer to tint, so
  /// the variants are generated ahead of time by `tool/recolour_outfits.py`:
  /// each character's clothing sits in a hue band nothing else on the figure
  /// shares, and rotating only that band repaints the outfit while leaving
  /// skin, hair and boots alone.
  static const Map<String, String> outfitColors = <String, String>{
    '#4E9FD1': 'blue',
    '#5FAE4B': 'green',
    '#E0A62B': 'yellow',
    '#9470D6': 'purple',
    '#DE6FA6': 'pink',
  };

  /// The hero's companion.
  ///
  /// Monsters rather than animals, and deliberately. These stand beside the
  /// hero head to foot; the animal set they replaced was a head in a circle,
  /// which read as a face floating next to a whole person. Kenney has no
  /// full-body animals in the flat-vector style the heroes are drawn in, and a
  /// companion that does not match the hero is worse than one that is not an
  /// animal. Composed from parts by `tool/build_buddies.py`.
  static const List<String> petAssets = <String>[
    'assets/story/pets/pip.png',
    'assets/story/pets/bloop.png',
    'assets/story/pets/sunny.png',
    'assets/story/pets/mint.png',
    'assets/story/pets/sky.png',
    'assets/story/pets/berry.png',
    'assets/story/pets/rusty.png',
    'assets/story/pets/snow.png',
    'assets/story/pets/cloud.png',
    'assets/story/pets/shadow.png',
  ];

  /// The picture of one hero, in one pose, wearing one outfit colour.
  ///
  /// A null colour draws the character as the pack drew them.
  static String assetFor(String hero, String pose, [String? colorHex]) {
    final suffix = colorHex == null ? '' : '-${outfitColors[colorHex] ?? ''}';
    return '$_dir/$hero/$pose$suffix.png';
  }

  /// Every hero picture, for the asset-integrity test.
  static List<String> get allHeroAssets => <String>[
    for (final hero in heroes)
      for (final pose in poses) ...<String>[
        assetFor(hero.value!, pose.value!),
        for (final hex in outfitColors.keys)
          assetFor(hero.value!, pose.value!, hex),
      ],
  ];

  /// The options shown in a feature's strip.
  static List<HeroOption> optionsFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.hero:
        return heroes;
      case HeroFeature.pose:
        return poses;
      case HeroFeature.pet:
        return <HeroOption>[
          const HeroOption(value: null, label: 'None'),
          for (final asset in petAssets)
            HeroOption(value: asset, label: _labelFromAsset(asset)),
        ];
    }
  }

  /// The swatches shown beneath a feature's strip.
  ///
  /// Only the hero row has any: the colour is what they are wearing, which is
  /// part of who they are rather than of what they are doing.
  static List<String> colorsFor(HeroFeature feature) =>
      feature == HeroFeature.hero
      ? outfitColors.keys.toList()
      : const <String>[];

  static String _labelFromAsset(String asset) {
    final file = asset.split('/').last.split('.').first;
    return file[0].toUpperCase() + file.substring(1);
  }

  static String labelFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.hero:
        return 'Hero';
      case HeroFeature.pose:
        return 'Pose';
      case HeroFeature.pet:
        return 'Pet';
    }
  }
}
