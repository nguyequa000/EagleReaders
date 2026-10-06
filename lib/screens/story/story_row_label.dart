import 'package:flutter/material.dart';

import 'story_theme.dart';

/// The small caps label that names the row of choices directly beneath it.
///
/// Deliberately not [StoryScaffold]'s own `sectionLabel`: that one renders
/// above the entire body, which puts it above the preview box rather than
/// above the options it names. Every step now shows the hero first and labels
/// the controls underneath, so the label travels with the controls.
class StoryRowLabel extends StatelessWidget {
  final String text;

  const StoryRowLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: StoryTheme.display(
        size: 12,
        color: StoryTheme.of(context).inkMuted,
        weight: 700,
        tracking: 1.6,
      ),
    );
  }
}
