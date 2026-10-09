import 'dart:math';

import 'sprout_prompt_data.dart';

/// Which part of the story a Sprout idea is for.
enum StoryStage { beginning, middle, end, any }

/// One idea question in the bank.
///
/// [text] may contain `{character}`, `{setting}` and `{mood}`, filled in from
/// the child's picks. An empty tag set fits every pick.
class SproutPrompt {
  final String text;
  final StoryStage stage;

  /// Hero keys, as in `HeroCatalog.heroes` (`'robot'`, not `'Robot'`).
  final Set<String> characters;

  /// Setting labels, as in `StoryOptions.settings`.
  final Set<String> settings;

  /// Mood labels, as in `StoryOptions.moods`.
  final Set<String> moods;

  const SproutPrompt(
    this.text, {
    this.stage = StoryStage.any,
    this.characters = const {},
    this.settings = const {},
    this.moods = const {},
  });

  bool get isTagged =>
      characters.isNotEmpty || settings.isNotEmpty || moods.isNotEmpty;

  bool fits(SproutRequest request) =>
      (stage == StoryStage.any || stage == request.stage) &&
      (characters.isEmpty || characters.contains(request.character)) &&
      (settings.isEmpty || settings.contains(request.setting)) &&
      (moods.isEmpty || moods.contains(request.mood));
}

/// Everything Sprout is allowed to know: the child's three picks and the part
/// of the story they're on.
///
/// **Never the child's text.** Not the story, not the title, not the hero's
/// typed name, not the summary's idea. That one rule is what keeps Sprout safe
/// to put next to a text field (TC-AI-SAFE-004 to -006), so keep it that way.
class SproutRequest {
  /// The hero key, e.g. `'explorer'`.
  final String character;
  final String? setting;
  final String? mood;
  final StoryStage stage;

  const SproutRequest({
    required this.character,
    required this.setting,
    required this.mood,
    required this.stage,
  });
}

/// Where the writer gets its ideas. Tests pass a fake.
abstract class SproutIdeaSource {
  String nextIdea(SproutRequest request);
}

/// The offline prompt bank. No network, no model: just questions picked to
/// fit the child's choices.
class LocalSproutIdeas implements SproutIdeaSource {
  static const fallback = 'What happens next?';

  final Random _random;
  final List<SproutPrompt> _prompts;

  /// What has been shown this session, per stage, so a prompt only comes back
  /// once every other match has had its turn.
  final Map<StoryStage, Set<SproutPrompt>> _shown = {};

  LocalSproutIdeas({
    Random? random,
    List<SproutPrompt> prompts = kSproutPrompts,
  }) : _random = random ?? Random(),
       _prompts = prompts;

  @override
  String nextIdea(SproutRequest request) {
    final matches = _prompts.where((p) => p.fits(request)).toList();
    if (matches.isEmpty) return fallback;

    final shown = _shown.putIfAbsent(request.stage, () => <SproutPrompt>{});
    var fresh = matches.where((p) => !shown.contains(p)).toList();
    if (fresh.isEmpty) {
      shown.removeAll(matches);
      fresh = matches;
    }
    // Ideas made for these picks first; the generic ones once those run out.
    final tagged = fresh.where((p) => p.isTagged).toList();
    final pool = tagged.isNotEmpty ? tagged : fresh;
    final prompt = pool[_random.nextInt(pool.length)];
    shown.add(prompt);

    final text = fill(prompt.text, request).trim();
    return text.isEmpty ? fallback : text;
  }

  /// Fills the placeholders: "the robot", "the forest", "outer space".
  static String fill(String text, SproutRequest request) => text
      .replaceAll('{character}', characterPhrase(request.character))
      .replaceAll('{setting}', settingPhrase(request.setting))
      .replaceAll('{mood}', (request.mood ?? 'happy').toLowerCase());

  /// Hero keys are the lowercased catalog labels (a test holds them to it).
  static String characterPhrase(String character) =>
      'the ${character.toLowerCase()}';

  static String settingPhrase(String? setting) {
    if (setting == null) return 'this place';
    final lower = setting.toLowerCase();
    // "Outer Space" reads naturally without an article.
    return lower == 'outer space' ? lower : 'the $lower';
  }
}

/// The hint under each guided heading. Static, not part of the rotation.
String stageHint(StoryStage stage, String character) => switch (stage) {
  StoryStage.beginning => 'Who is your story about? Where are they?',
  StoryStage.middle => 'What surprise or problem happens?',
  StoryStage.end ||
  StoryStage.any => 'How does it end? How does $character feel?',
};
