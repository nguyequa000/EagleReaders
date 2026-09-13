import 'package:flutter/material.dart';

import 'story_button.dart';
import 'story_sprout_bubble.dart';
import 'story_theme.dart';

/// Shown after the child turns the last page of their story.
///
/// Deliberately keeps its back control: reaching here is one tap on the
/// reader's "next page" arrow, so a child who taps it by accident needs a way
/// back to what they were reading.
///
/// A third choice — re-reading an earlier story — belongs here too, but nothing
/// is saved yet, so it is left out rather than shown dead.
class StoryFinishedScreen extends StatelessWidget {
  final VoidCallback onCreateAnother;
  final VoidCallback onReturnHome;

  const StoryFinishedScreen({
    super.key,
    required this.onCreateAnother,
    required this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoryTheme.ground,
      appBar: AppBar(
        title: Text(
          'The End!',
          style: StoryTheme.display(size: 19, color: Colors.white, weight: 600),
        ),
        backgroundColor: StoryTheme.brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const StorySproutBubble(
                message: 'You finished your story! '
                    'What would you like to do now?',
                accent: StoryTheme.accentComplete,
              ),
              const Spacer(),
              StoryButton(
                label: 'Create Another Story',
                accent: StoryTheme.accentCharacter,
                showArrow: false,
                onPressed: onCreateAnother,
              ),
              const SizedBox(height: 12),
              StoryButton(
                label: 'Return Home',
                accent: StoryTheme.accentComplete,
                showArrow: false,
                onPressed: onReturnHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
