import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/avataaars.dart';
import 'package:flutter/foundation.dart';

/// The five rows of the hero builder.
enum HeroFeature { avatar, hair, hat, outfit, pet }

/// A complete facial expression — a pairing of eyes and mouth.
///
/// An expression is not something the child picks while building their hero.
/// It is decided by the **mood of the story**, so choosing "Spooky" widens the
/// hero's eyes and choosing "Funny" makes them pull a face.
///
/// It has to be a pair: Avataaars keeps eyes and mouth in separate slots, so
/// setting only `eyes` leaves the mouth wherever the seed left it — which is
/// how every hero ended up wearing the same open mouth.
@immutable
class HeroExpression {
  final String id;
  final String label;
  final String eyes;
  final String mouth;

  const HeroExpression({
    required this.id,
    required this.label,
    required this.eyes,
    required this.mouth,
  });
}

/// One selectable option within a feature row.
@immutable
class HeroOption {
  /// The value written into the avatar options, or the asset path for a pet.
  ///
  /// Null means "none" — the empty slot a hat or a pet row needs so a child can
  /// take one off again.
  final String? value;

  /// What the child reads on the tile.
  final String label;

  const HeroOption({required this.value, required this.label});
}

/// What the builder can offer, read out of the Avataaars style definition.
///
/// Nothing here is a hand-maintained list of strings. The variants and the
/// colour swatches both come from the style's own catalogue, so when the
/// package updates the rows follow it instead of silently drifting out of date.
class HeroCatalog {
  const HeroCatalog._();

  static Style? _style;

  /// The parsed Avataaars style. Parsed once — it decodes a 124KB JSON
  /// document, which is not something to redo on every rebuild.
  static Style get style => _style ??= Style.parse(avataaars);

  static Map<String, Object?> get _definition => style.definition();

  /// Variants of `top` that cover the head rather than style the hair.
  ///
  /// Avataaars has no separate hat slot: `top` is one layer holding either a
  /// hairstyle or a piece of headwear, and choosing one replaces the other.
  /// The wireframe asks for two rows, so the split lives here and
  /// [HeroConfig] remembers the hair underneath a hat.
  static const Set<String> hatVariants = <String>{
    'hat',
    'hijab',
    'turban',
    'winterHat1',
    'winterHat02',
    'winterHat03',
    'winterHat04',
  };

  /// Expressions, keyed by the story mood that selects them.
  ///
  /// Curated rather than generated: the catalogue's own ids are clinical
  /// ('winkWacky', 'screamOpen', 'vomit') and not every eyes/mouth pairing
  /// reads as a feeling.
  static const List<HeroExpression> expressions = <HeroExpression>[
    HeroExpression(id: 'happy', label: 'Happy', eyes: 'happy', mouth: 'smile'),
    HeroExpression(id: 'silly', label: 'Silly', eyes: 'winkWacky', mouth: 'tongue'),
    HeroExpression(id: 'wow', label: 'Wow!', eyes: 'surprised', mouth: 'screamOpen'),
    HeroExpression(id: 'brave', label: 'Brave', eyes: 'squint', mouth: 'serious'),
    HeroExpression(id: 'calm', label: 'Calm', eyes: 'default', mouth: 'default'),
  ];

  static HeroExpression? expressionById(String? id) {
    if (id == null) return null;
    for (final expression in expressions) {
      if (expression.id == id) return expression;
    }
    return null;
  }

  /// Which face the hero wears for a given story mood.
  ///
  /// Mood labels come from [StoryOptions.moods]. An unknown or unchosen mood
  /// falls back to Happy rather than to nothing, so the hero is never
  /// expressionless while the child is still deciding.
  static HeroExpression expressionForMood(String? mood) {
    switch (mood?.toLowerCase()) {
      case 'funny':
        return expressionById('silly')!;
      case 'spooky':
        return expressionById('wow')!;
      case 'adventurous':
        return expressionById('brave')!;
      case 'calm':
        return expressionById('calm')!;
      default:
        return expressionById('happy')!;
    }
  }

  /// The base figures offered by the Avatar row, as skin tones.
  ///
  /// The Avatar row picks a *bare* base — no hair, no hat, no expression — so
  /// the only thing that distinguishes one base from another is its skin tone.
  /// Presenting them as whole faces rather than colour dots is also the better
  /// control for a child: they choose a person, not a swatch.
  static List<String> get skinTones => colorsFor(HeroFeature.hair).isEmpty
      ? const <String>[]
      : _swatches('skin');

  static List<String> _swatches(String key) {
    final colors = _definition['colors'] as Map<String, Object?>;
    final body = colors[key] as Map<String, Object?>?;
    if (body == null) return const <String>[];
    return (body['values'] as List<Object?>).cast<String>();
  }

  /// Kenney's CC0 animal portraits. Not from DiceBear — no avatar style has
  /// pets, so these are bundled assets rather than catalogue entries.
  static const List<String> petAssets = <String>[
    'assets/story/pets/panda.png',
    'assets/story/pets/monkey.png',
    'assets/story/pets/rabbit.png',
    'assets/story/pets/penguin.png',
    'assets/story/pets/pig.png',
    'assets/story/pets/giraffe.png',
    'assets/story/pets/elephant.png',
    'assets/story/pets/parrot.png',
  ];

  /// The DiceBear component each feature row writes to.
  static String? componentFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.avatar:
        // The Avatar row swaps the seed rather than any one component.
        return null;
      case HeroFeature.hair:
      case HeroFeature.hat:
        return 'top';
      case HeroFeature.outfit:
        return 'clothes';
      case HeroFeature.pet:
        return null;
    }
  }

  /// The colour axis shown beneath each row, or null where the row has none.
  static String? colorKeyFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.avatar:
        // No colour row: the Avatar row is itself the skin-tone choice, shown
        // as faces rather than dots. A second control for the same value would
        // be two ways to change one thing.
        return null;
      case HeroFeature.hair:
        return 'hair';
      case HeroFeature.hat:
        return 'hat';
      case HeroFeature.outfit:
        return 'clothes';
      case HeroFeature.pet:
        return null;
    }
  }

  static List<String> _variantsOf(String component) {
    final components = _definition['components'] as Map<String, Object?>;
    final body = components[component] as Map<String, Object?>;
    return (body['variants'] as Map<String, Object?>).keys.toList();
  }

  /// The options shown in a feature's strip.
  static List<HeroOption> optionsFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.pet:
        return <HeroOption>[
          const HeroOption(value: null, label: 'None'),
          for (final asset in petAssets)
            HeroOption(value: asset, label: _labelFromAsset(asset)),
        ];
      case HeroFeature.hat:
        return <HeroOption>[
          const HeroOption(value: null, label: 'None'),
          for (final variant in _variantsOf('top'))
            if (hatVariants.contains(variant))
              HeroOption(value: variant, label: humanize(variant)),
        ];
      case HeroFeature.hair:
        return <HeroOption>[
          for (final variant in _variantsOf('top'))
            if (!hatVariants.contains(variant))
              HeroOption(value: variant, label: humanize(variant)),
        ];
      case HeroFeature.avatar:
        return <HeroOption>[
          for (var i = 0; i < skinTones.length; i++)
            HeroOption(value: skinTones[i], label: 'Hero ${i + 1}'),
        ];
      case HeroFeature.outfit:
        return <HeroOption>[
          for (final variant in _variantsOf('clothes'))
            HeroOption(value: variant, label: humanize(variant)),
        ];
    }
  }

  /// The swatches shown beneath a feature's strip, as `#rrggbb` strings.
  static List<String> colorsFor(HeroFeature feature) {
    final key = colorKeyFor(feature);
    if (key == null) return const <String>[];
    final colors = _definition['colors'] as Map<String, Object?>;
    final body = colors[key] as Map<String, Object?>?;
    if (body == null) return const <String>[];
    return (body['values'] as List<Object?>).cast<String>();
  }

  static String _labelFromAsset(String asset) {
    final file = asset.split('/').last.split('.').first;
    return file[0].toUpperCase() + file.substring(1);
  }

  /// Turns a catalogue id into something a child can read:
  /// `shirtCrewNeck` becomes `Shirt Crew Neck`, `winterHat02` becomes
  /// `Winter Hat 02`.
  static String humanize(String id) {
    final spaced = id
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Za-z])(\d)'), (m) => '${m[1]} ${m[2]}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String labelFor(HeroFeature feature) {
    switch (feature) {
      case HeroFeature.avatar:
        return 'Avatar';
      case HeroFeature.hair:
        return 'Hair';
      case HeroFeature.hat:
        return 'Hat';
      case HeroFeature.outfit:
        return 'Outfit';
      case HeroFeature.pet:
        return 'Pet';
    }
  }
}
