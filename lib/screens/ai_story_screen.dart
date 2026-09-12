import 'package:flutter/material.dart';

import 'story/story_config.dart';
import 'story/story_theme.dart';

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
      backgroundColor: StoryTheme.ground,
      appBar: AppBar(
        title: Text(
          'Your Story',
          style: StoryTheme.display(size: 19, color: Colors.white, weight: 600),
        ),
        backgroundColor: StoryTheme.brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildDetailBanner(),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  storyText,
                  style: StoryTheme.body(size: 17, height: 1.7),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StoryTheme.card,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(color: StoryTheme.shadow),
        boxShadow: StoryTheme.hardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'STORY PREVIEW',
            style: StoryTheme.display(
              size: 12,
              color: StoryTheme.inkMuted,
              weight: 600,
              tracking: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _bannerLine('Character', config.character, StoryTheme.accentCharacter),
          _bannerLine('Mood', config.mood, StoryTheme.accentMood),
          _bannerLine('Setting', config.setting, StoryTheme.accentSetting),
        ],
      ),
    );
  }

  Widget _bannerLine(String caption, String? value, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            '$caption: ',
            style: StoryTheme.body(size: 14, color: StoryTheme.inkMuted),
          ),
          Text(
            value ?? 'unknown',
            style: StoryTheme.display(size: 14, color: accent, weight: 600),
          ),
        ],
      ),
    );
  }
}
