import 'hero_config.dart';

/// Carries the child's selections across all four steps of the story flow.
class StoryConfig {
  /// The hero built in step 1.
  ///
  /// Never null: a seeded [HeroConfig] already describes a complete character,
  /// so there is no "before a hero exists" state for the rest of the flow to
  /// defend against.
  final HeroConfig hero;

  final String? mood;
  final String? setting;

  const StoryConfig({
    this.hero = const HeroConfig(),
    this.mood,
    this.setting,
  });

  StoryConfig copyWith({
    HeroConfig? hero,
    String? mood,
    String? setting,
  }) {
    return StoryConfig(
      hero: hero ?? this.hero,
      mood: mood ?? this.mood,
      setting: setting ?? this.setting,
    );
  }
}
