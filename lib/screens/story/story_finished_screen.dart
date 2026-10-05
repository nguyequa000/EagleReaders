import 'package:flutter/material.dart';

import 'paper_background.dart';
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
    final palette = StoryTheme.of(context);

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        title: Text(
          'The End!',
          style: StoryTheme.display(
            size: 21,
            color: palette.headerInk,
            weight: 700,
          ),
        ),
        backgroundColor: palette.header,
        foregroundColor: palette.headerInk,
        elevation: 0,
        // The same cut the step scaffold puts under its header, so this
        // screen reads as the last page of the same book.
        shape: Border(
          bottom: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      body: PaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StorySproutBubble(
                  message:
                      'You finished your story! '
                      'What would you like to do now?',
                  accent: palette.action,
                ),
                const Spacer(),
                StoryButton(
                  label: 'Create Another Story',
                  accent: palette.action,
                  showArrow: false,
                  onPressed: onCreateAnother,
                ),
                const SizedBox(height: 12),
                StoryButton(
                  label: 'Return Home',
                  accent: palette.action,
                  showArrow: false,
                  filled: false,
                  onPressed: onReturnHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
