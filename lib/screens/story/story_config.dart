/// Carries the child's selections across all four steps of the story flow.
class StoryConfig {
  final String? character;
  final String? mood;
  final String? setting;

  const StoryConfig({this.character, this.mood, this.setting});

  StoryConfig copyWith({String? character, String? mood, String? setting}) {
    return StoryConfig(
      character: character ?? this.character,
      mood: mood ?? this.mood,
      setting: setting ?? this.setting,
    );
  }
}
