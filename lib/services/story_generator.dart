import 'package:firebase_ai/firebase_ai.dart';

/// Writes short child-friendly stories with Gemini via Firebase AI Logic.
class StoryGenerator {
  const StoryGenerator();

  static const _model = 'gemini-3.8-flash';

  // 300-500 words is roughly 600-900 tokens; leaves headroom below the limit.
  static const _maxOutputTokens = 2048;

  Future<String> generateStory({
    required String character,
    required String mood,
    required String setting,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _model,
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        maxOutputTokens: _maxOutputTokens,
        temperature: 1.0,
      ),
    );
    final response = await model
        .generateContent([
          Content.text(
            storyPrompt(character: character, mood: mood, setting: setting),
          ),
        ])
        .timeout(const Duration(seconds: 45));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      // Blocked or filtered prompts come back with no candidate text.
      throw const StoryGenerationException(
        'Sprout could not finish that story. Try different choices!',
      );
    }
    return text;
  }

  static String storyPrompt({
    required String character,
    required String mood,
    required String setting,
  }) =>
      'Write a bedtime story. Main character: $character. '
      'Mood: $mood. Setting: $setting.';

  static const _systemInstruction =
      'You are Sprout, a warm storyteller for children ages 6 to 9. '
      'Write a single story of 300 to 500 words in simple words and short '
      'sentences. Keep it gentle and age-appropriate, with a happy or '
      'reassuring ending. Use plain paragraphs only - no titles, headings, '
      'markdown, or bullet points.';
}

class StoryGenerationException implements Exception {
  const StoryGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
