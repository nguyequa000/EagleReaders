import 'package:flutter/foundation.dart';

/// One selectable choice in a story step.
@immutable
class StoryOption {
  /// User-visible name. Several of these are asserted verbatim by the flow
  /// tests — see the Global Constraints in the implementation plan.
  final String label;

  /// Bundled OpenMoji SVG path.
  final String asset;

  const StoryOption({required this.label, required this.asset});
}

/// The three fixed option catalogs.
class StoryOptions {
  const StoryOptions._();

  static const List<StoryOption> characters = <StoryOption>[
    StoryOption(label: 'Brave Knight', asset: 'assets/story/characters/knight.svg'),
    StoryOption(label: 'Friendly Dragon', asset: 'assets/story/characters/dragon.svg'),
    StoryOption(label: 'Clever Fox', asset: 'assets/story/characters/fox.svg'),
    StoryOption(label: 'Magic Fairy', asset: 'assets/story/characters/fairy.svg'),
  ];

  static const List<StoryOption> moods = <StoryOption>[
    StoryOption(label: 'Funny', asset: 'assets/story/moods/funny.svg'),
    StoryOption(label: 'Adventurous', asset: 'assets/story/moods/adventurous.svg'),
    StoryOption(label: 'Spooky', asset: 'assets/story/moods/spooky.svg'),
    StoryOption(label: 'Calm', asset: 'assets/story/moods/calm.svg'),
  ];

  static const List<StoryOption> settings = <StoryOption>[
    StoryOption(label: 'Forest', asset: 'assets/story/settings/forest.svg'),
    StoryOption(label: 'Ocean', asset: 'assets/story/settings/ocean.svg'),
    StoryOption(label: 'City', asset: 'assets/story/settings/city.svg'),
    StoryOption(label: 'Outer Space', asset: 'assets/story/settings/space.svg'),
  ];

  /// Looks up an option by its label. Returns null for a null or unknown label,
  /// which is what the summary screen needs for a not-yet-made choice.
  static StoryOption? byLabel(List<StoryOption> options, String? label) {
    if (label == null) return null;
    for (final option in options) {
      if (option.label == label) return option;
    }
    return null;
  }
}
