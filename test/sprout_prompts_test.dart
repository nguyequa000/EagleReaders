import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story/story_option.dart';
import 'package:storysprout/services/sprout_prompt_data.dart';
import 'package:storysprout/services/sprout_prompts.dart';

void main() {
  final heroes = [for (final h in HeroCatalog.heroes) h.value!];
  final settings = [for (final s in StoryOptions.settings) s.label];
  final moods = [for (final m in StoryOptions.moods) m.label];
  const stages = [StoryStage.beginning, StoryStage.middle, StoryStage.end];

  SproutRequest request(
    String hero,
    String setting,
    String mood,
    StoryStage stage,
  ) => SproutRequest(
    character: hero,
    setting: setting,
    mood: mood,
    stage: stage,
  );

  test('hero keys are the lowercased labels, so "the robot" reads right', () {
    for (final hero in HeroCatalog.heroes) {
      expect(hero.value, hero.label.toLowerCase());
    }
  });

  test('every combination of picks gets a filled idea for every stage', () {
    final ideas = LocalSproutIdeas(random: Random(1));
    for (final hero in heroes) {
      for (final setting in settings) {
        for (final mood in moods) {
          for (final stage in stages) {
            final idea = ideas.nextIdea(request(hero, setting, mood, stage));
            expect(idea, isNotEmpty);
            expect(idea, isNot(contains('{')));
            expect(idea, isNot(contains('}')));
            expect(idea, endsWith('?'));
          }
        }
      }
    }
  });

  test('every option has prompts made for it', () {
    for (final hero in heroes) {
      expect(
        kSproutPrompts.where((p) => p.characters.contains(hero)),
        hasLength(greaterThanOrEqualTo(2)),
        reason: hero,
      );
    }
    for (final setting in settings) {
      expect(
        kSproutPrompts.where((p) => p.settings.contains(setting)),
        hasLength(greaterThanOrEqualTo(2)),
        reason: setting,
      );
    }
    for (final mood in moods) {
      expect(
        kSproutPrompts.where((p) => p.moods.contains(mood)),
        hasLength(greaterThanOrEqualTo(2)),
        reason: mood,
      );
    }
  });

  test('tags only name real options', () {
    for (final prompt in kSproutPrompts) {
      expect(heroes, containsAll(prompt.characters), reason: prompt.text);
      expect(settings, containsAll(prompt.settings), reason: prompt.text);
      expect(moods, containsAll(prompt.moods), reason: prompt.text);
    }
  });

  test('every prompt is a short, plain question', () {
    for (final prompt in kSproutPrompts) {
      final text = prompt.text;
      expect(text, endsWith('?'), reason: text);
      expect(
        text.split(RegExp(r'\s+')).length,
        lessThanOrEqualTo(12),
        reason: text,
      );
      expect(text, isNot(matches(RegExp(r'\d'))), reason: text);
      for (final link in ['http', 'www', '.com']) {
        expect(text.toLowerCase(), isNot(contains(link)), reason: text);
      }
    }
  });

  test('no prompt uses an unkind or frightening word', () {
    const blocklist = [
      'kill',
      'blood',
      'die',
      'dead',
      'death',
      'gun',
      'knife',
      'kiss',
      'hate',
      'stupid',
      'scary',
      'monster attack',
      'hurt',
      'cry',
      'ghost',
    ];
    for (final prompt in kSproutPrompts) {
      final words = prompt.text.toLowerCase();
      for (final bad in blocklist) {
        expect(
          RegExp('\\b$bad\\b').hasMatch(words),
          isFalse,
          reason: '"${prompt.text}" contains "$bad"',
        );
      }
    }
  });

  test('no repeats within a stage until every match has been shown', () {
    final ideas = LocalSproutIdeas(random: Random(7));
    final req = request('robot', 'Ocean', 'Calm', StoryStage.middle);
    final matches = kSproutPrompts.where((p) => p.fits(req)).length;

    final seen = <String>{};
    for (var i = 0; i < matches; i++) {
      expect(seen.add(ideas.nextIdea(req)), isTrue, reason: 'repeat at $i');
    }
    // Then the round starts again rather than running dry.
    expect(ideas.nextIdea(req), isIn(seen));
  });

  test('ideas for the picks come before the generic ones', () {
    final ideas = LocalSproutIdeas(random: Random(3));
    final req = request('monster', 'Outer Space', 'Spooky', StoryStage.middle);
    final tagged = kSproutPrompts
        .where((p) => p.fits(req) && p.isTagged)
        .map((p) => LocalSproutIdeas.fill(p.text, req))
        .toSet();
    for (var i = 0; i < tagged.length; i++) {
      expect(ideas.nextIdea(req), isIn(tagged));
    }
  });

  test('placeholders read naturally', () {
    final req = request('explorer', 'Outer Space', 'Calm', StoryStage.any);
    expect(
      LocalSproutIdeas.fill('{character} in {setting}', req),
      'the explorer in outer space',
    );
    expect(
      LocalSproutIdeas.fill(
        '{setting}',
        request('pal', 'Forest', 'Calm', StoryStage.any),
      ),
      'the forest',
    );
  });

  test('an empty bank still gives an idea', () {
    final ideas = LocalSproutIdeas(prompts: const []);
    expect(
      ideas.nextIdea(request('pal', 'City', 'Funny', StoryStage.end)),
      LocalSproutIdeas.fallback,
    );
  });
}
