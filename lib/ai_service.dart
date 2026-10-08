import 'package:firebase_ai/firebase_ai.dart';
import 'screens/story/hero_catalog.dart';
import 'screens/story/story_config.dart';

// Anything that goes wrong on an AI call becomes one of these, so screens can
// show [message] to a kid without unpacking SDK error types.
class AiFailure implements Exception {
  final String message;

  const AiFailure(this.message);

  @override
  String toString() => message;
}

// Single home for every Gemini / API call in Story Sprout.
//
// Talks to Gemini through Firebase AI Logic, so there is no API key in the app
// and no extra config file — it reuses the Firebase project that main.dart
// already initializes. Firebase.initializeApp() must have finished before any
// method here is called.
//
// Usage: final story = await AiService.instance.generateStory(config);
class AiService {
  AiService._();

  static final AiService instance = AiService._();

  // Free on the Gemini Developer API's no-cost tier, which is what the Spark
  // plan gives us — no billing account, no spend. Change it here and every
  // call moves.
  static const String textModel = 'gemini-3.8-flash';

  // Built on first use, then reused — creating a model per call is wasteful.
  GenerativeModel? _storyteller;

  GenerativeModel get _model {
    return _storyteller ??= FirebaseAI.googleAI().generativeModel(
      model: textModel,
      systemInstruction: Content.system(_systemInstructions),
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 1200,
        // gemini-3.8-flash thinks by default, and thinking tokens count
        // against maxOutputTokens — left alone it burned ~1120 of 1200 tokens
        // reasoning and truncated the story mid-sentence. Low is the lowest
        // level this model accepts (minimal is rejected) and it lands a full
        // 300-word story in a few seconds.
        thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
      ),
      safetySettings: _kidSafeSettings,
    );
  }

  // Full story in one shot. Use this when the screen shows a loading spinner
  // and then the finished page.
  Future<String> generateStory(StoryConfig config, {int gradeLevel = 2}) async {
    final prompt = [Content.text(_storyPrompt(config, gradeLevel))];

    return _guard(() async {
      final response = await _model.generateContent(prompt);
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw const AiFailure(
          'The story came back empty. Try picking your story again.',
        );
      }
      return text;
    });
  }

  // Same story, delivered in pieces as it is written, so the reader can watch
  // it appear instead of waiting on a blank screen. Each event is the next
  // chunk of text, not the whole story so far.
  Stream<String> streamStory(StoryConfig config, {int gradeLevel = 2}) async* {
    final prompt = [Content.text(_storyPrompt(config, gradeLevel))];

    try {
      await for (final response in _model.generateContentStream(prompt)) {
        final chunk = response.text;
        if (chunk != null && chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } on AiFailure {
      rethrow;
    } catch (error) {
      throw _describe(error);
    }
  }

  // Escape hatch for the AI features that are not story generation yet
  // (comprehension questions, vocabulary help, summaries). Keeps every model
  // call inside this file instead of scattered across screens.
  Future<String> generateText(String prompt) {
    return _guard(() async {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        throw const AiFailure('No response came back. Please try again.');
      }
      return text;
    });
  }

  String _storyPrompt(StoryConfig config, int gradeLevel) {
    final character = _describeHero(config);
    final mood = config.mood ?? 'wonderful';
    final setting = config.setting ?? 'a magical place';

    return '''
Write a short original story for a grade $gradeLevel reader.

Main character: $character
Mood: $mood
Setting: $setting

Rules:
- 250 to 350 words, in 5 to 7 short paragraphs.
- Sentences a grade $gradeLevel reader can read on their own.
- The $mood mood should come through in what happens, not by naming it.
- Give the character one small problem and let them solve it themselves.
- End on a warm, finished ending. Nothing scary, sad, or unresolved.
- Plain text only: no markdown, asterisks, headings, or title line. Start with
  the first sentence of the story.''';
  }

  // The hero is a built character now rather than a string, so describe it
  // from the catalogue label plus the name the child typed, if any:
  // "an explorer named Robin", or just "a robot".
  String _describeHero(StoryConfig config) {
    final hero = config.hero;
    final kind = HeroCatalog.heroes
        .firstWhere(
          (option) => option.value == hero.effectiveCharacter,
          orElse: () => HeroCatalog.heroes.first,
        )
        .label
        .toLowerCase();
    final article = 'aeiou'.contains(kind[0]) ? 'an' : 'a';
    final name = hero.name?.trim();
    return (name == null || name.isEmpty)
        ? '$article $kind'
        : '$article $kind named $name';
  }

  // Runs [call] and turns every SDK failure into an AiFailure.
  Future<String> _guard(Future<String> Function() call) async {
    try {
      return await call();
    } on AiFailure {
      rethrow;
    } catch (error) {
      throw _describe(error);
    }
  }

  // response.text throws when a prompt or answer trips a safety filter, so the
  // blocked cases land here alongside network and quota problems.
  AiFailure _describe(Object error) {
    if (error is ServiceApiNotEnabled) {
      return const AiFailure(
        'Firebase AI Logic is not enabled for this project yet. '
        'Turn it on in the Firebase console under AI Logic.',
      );
    }
    if (error is QuotaExceeded) {
      // The no-cost tier allows only 5 requests per minute for this model. On
      // the Spark plan that is a hard ceiling — there is no billing to raise it
      // — so a classroom all tapping Create at once will land here.
      return const AiFailure(
        'Lots of stories are being written right now. '
        'Wait a minute and try again.',
      );
    }
    if (error is FirebaseAIException) {
      // Covers blocked prompts and blocked answers.
      return const AiFailure(
        'That story idea did not work out. Try a different character or mood.',
      );
    }
    return const AiFailure(
      'Could not reach the story writer. Check your connection and try again.',
    );
  }

  static const String _systemInstructions = '''
You write short, gentle, age-appropriate stories for elementary school children
using the Story Sprout app. Keep language simple and concrete, keep every story
positive and complete, and never include violence, romance, frightening imagery,
or anything a teacher would not read aloud in class.''';

  // Strictest useful threshold, since the audience is children.
  static final List<SafetySetting> _kidSafeSettings = [
    SafetySetting(HarmCategory.harassment, HarmBlockThreshold.low, null),
    SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.low, null),
    SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.low, null),
    SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.low, null),
  ];
}
