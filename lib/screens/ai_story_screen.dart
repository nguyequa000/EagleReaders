import 'package:flutter/material.dart';
import 'story/story_config.dart';

class StoryReaderScreen extends StatelessWidget {
  final StoryConfig config;

  const StoryReaderScreen({super.key, required this.config});

  String _buildStoryText() {
    final character = config.character ?? 'a curious friend';
    final mood = config.mood ?? 'wonderful';
    final setting = config.setting ?? 'a magical place';

    final moodSentence = switch (mood.toLowerCase()) {
      'funny' => 'Every turn in the tale made everyone giggle and laugh.',
      'adventurous' => 'Every day felt like the next big adventure waiting to happen.',
      'spooky' => 'The shadows whispered secrets and the air crackled with mystery.',
      'calm' => 'The story moved like a gentle stream, soft and peaceful.',
      _ => 'The story had a special feeling all its own.',
    };

    return '''
Once upon a time, in $setting, there lived $character.

$character loved to explore and discover new things. Today was special because the whole world felt full of $mood energy.

$moodSentence

Along the way, $character met new friends, solved little puzzles, and discovered that the best part of any journey is how much joy it brings.

And when the sun began to set, $character knew that every day could be as magical as this one. The end.''';
  }

  @override
  Widget build(BuildContext context) {
    final storyText = _buildStoryText();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Story'),
        backgroundColor: const Color(0xFF3D6B1A),
      ),
      body: Container(
        color: const Color(0xFFF5F0DC),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDetailBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  storyText,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Story Preview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D6B1A),
            ),
          ),
          const SizedBox(height: 8),
          Text('Character: ${config.character ?? 'unknown'}'),
          Text('Mood: ${config.mood ?? 'unknown'}'),
          Text('Setting: ${config.setting ?? 'unknown'}'),
        ],
      ),
    );
  }
}
