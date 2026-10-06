import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';

void main() {
  test('defaults to a complete hero and no other choices', () {
    const config = StoryConfig();
    // The hero is never null — an unbuilt one already draws a whole
    // character, so the later steps never render an empty preview box.
    expect(config.hero, isNotNull);
    expect(config.hero.assetPath, startsWith('assets/story/toon/'));
    expect(config.mood, isNull);
    expect(config.setting, isNull);
  });

  test('copyWith replaces only the named field', () {
    final config = StoryConfig(
      hero: const HeroConfig().withOption(HeroFeature.pose, 'jump'),
    );
    final updated = config.copyWith(mood: 'Spooky');

    expect(updated.hero.pose, 'jump');
    expect(updated.mood, 'Spooky');
    expect(updated.setting, isNull);
  });

  test('copyWith with no arguments preserves every field', () {
    final config = StoryConfig(
      hero: const HeroConfig(name: 'Sparkle'),
      mood: 'Calm',
      setting: 'Ocean',
    );
    final same = config.copyWith();

    expect(same.hero.name, 'Sparkle');
    expect(same.mood, 'Calm');
    expect(same.setting, 'Ocean');
  });

  test('swapping the hero leaves the story choices alone', () {
    const config = StoryConfig(mood: 'Funny', setting: 'Forest');
    final rebuilt = config.copyWith(
      hero: const HeroConfig().withOption(HeroFeature.pose, 'turban'),
    );

    expect(rebuilt.hero.pose, 'turban');
    expect(rebuilt.mood, 'Funny', reason: 'editing the hero is not a reset');
    expect(rebuilt.setting, 'Forest');
  });
}
