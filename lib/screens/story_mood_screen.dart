import 'package:flutter/material.dart';

import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 2 of 4 — mood selection.
class StoryMoodScreen extends StatefulWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  const StoryMoodScreen({
    super.key,
    required this.config,
    this.onBack,
    this.onNext,
  });

  @override
  State<StoryMoodScreen> createState() => _StoryMoodScreenState();
}

class _StoryMoodScreenState extends State<StoryMoodScreen> {
  static const int _step = 2;

  /// Seeded from the incoming config so stepping Back re-enters the screen
  /// with the child's existing choice still highlighted and Next still live.
  late String? _selected = widget.config.mood;

  void _handleNext() {
    final selected = _selected;
    if (selected == null) return;
    widget.onNext?.call(widget.config.copyWith(mood: selected));
  }

  @override
  Widget build(BuildContext context) {
    return StoryScaffold(
      step: _step,
      prompt: 'Great choice! Now, what kind of mood should your story have?',
      sectionLabel: 'CHOOSE A MOOD',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: StoryTheme.accentForStep(_step),
        onPressed: _selected == null ? null : _handleNext,
      ),
      child: StoryOptionGrid(
        options: StoryOptions.moods,
        selectedLabel: _selected,
        accent: StoryTheme.accentForStep(_step),
        onSelect: (label) => setState(() => _selected = label),
      ),
    );
  }
}
