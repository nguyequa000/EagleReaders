import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_config.dart';

void main() {
  test('defaults to all-null', () {
    const config = StoryConfig();
    expect(config.character, isNull);
    expect(config.mood, isNull);
    expect(config.setting, isNull);
  });

  test('copyWith replaces only the named field', () {
    const config = StoryConfig(character: 'Clever Fox');
    final updated = config.copyWith(mood: 'Spooky');

    expect(updated.character, 'Clever Fox');
    expect(updated.mood, 'Spooky');
    expect(updated.setting, isNull);
  });

  test('copyWith with no arguments preserves every field', () {
    const config = StoryConfig(
      character: 'Magic Fairy',
      mood: 'Calm',
      setting: 'Ocean',
    );
    final same = config.copyWith();

    expect(same.character, 'Magic Fairy');
    expect(same.mood, 'Calm');
    expect(same.setting, 'Ocean');
  });
}
