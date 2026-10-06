import 'package:flutter/material.dart';

import 'story/story_config.dart';
import 'story/story_theme.dart';

class StoryReaderScreen extends StatelessWidget {
  final StoryConfig config;

  /// Turn the last page — opens the screen that asks what to do next.
  ///
  /// Optional: when null the screen renders with no page-turn control and keeps
  /// ordinary back behaviour, which is how it behaves for any caller that
  /// predates the story flow wiring it up.
  final VoidCallback? onNextPage;

  const StoryReaderScreen({super.key, required this.config, this.onNextPage});

  String _buildStoryText() {
    // A named hero carries the prose; an unnamed one falls back to a phrase
    // that still reads as a sentence.
    final character = config.hero.name ?? 'a brave hero';
    final mood = config.mood ?? 'wonderful';
    final setting = config.setting ?? 'a magical place';

    final moodSentence = switch (mood.toLowerCase()) {
      'funny' => 'Every turn in the tale made everyone giggle and laugh.',
      'adventurous' =>
        'Every day felt like the next big adventure waiting to happen.',
      'spooky' =>
        'The shadows whispered secrets and the air crackled with mystery.',
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
    final palette = StoryTheme.of(context);
    final storyText = _buildStoryText();

    // The reader replaces the 4-step flow rather than stacking on it, so there
    // is nothing meaningful behind this screen to go back to. Blocking pop
    // keeps the hardware back gesture from dropping a child onto a half-built
    // story; the page-turn arrow is the way forward.
    return PopScope(
      canPop: onNextPage == null,
      child: Scaffold(
        backgroundColor: palette.ground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Your Story',
            style: StoryTheme.display(
              size: 19,
              color: palette.headerInk,
              weight: 600,
            ),
          ),
          backgroundColor: palette.header,
          foregroundColor: palette.headerInk,
          elevation: 0,
          actions: <Widget>[
            if (onNextPage != null)
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Next page',
                onPressed: onNextPage,
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildDetailBanner(palette),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    storyText,
                    style: StoryTheme.body(
                      size: 17,
                      color: palette.ink,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBanner(StoryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(color: palette.line),
        boxShadow: palette.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'STORY PREVIEW',
            style: StoryTheme.display(
              size: 12,
              color: palette.inkMuted,
              weight: 600,
              tracking: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _bannerLine(palette, 'Hero', config.hero.name ?? 'Your hero'),
          _bannerLine(palette, 'Mood', config.mood),
          _bannerLine(palette, 'Setting', config.setting),
        ],
      ),
    );
  }

  Widget _bannerLine(StoryPalette palette, String caption, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            '$caption: ',
            style: StoryTheme.body(size: 14, color: palette.inkMuted),
          ),
          Text(
            value ?? 'unknown',
            style: StoryTheme.display(
              size: 14,
              color: palette.ink,
              weight: 600,
            ),
          ),
        ],
      ),
    );
  }
}
