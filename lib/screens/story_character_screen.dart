import 'package:flutter/material.dart';

import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 1 of 4 — character selection.
class StoryCharacterScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  const StoryCharacterScreen({super.key, this.onBack, this.onNext});

  @override
  State<StoryCharacterScreen> createState() => _StoryCharacterScreenState();
}

class _StoryCharacterScreenState extends State<StoryCharacterScreen> {
  static const int _step = 1;

  String? _selected;

  void _handleNext() {
    final selected = _selected;
    if (selected == null) return;
    widget.onNext?.call(StoryConfig(character: selected));
  }

  @override
  Widget build(BuildContext context) {
    return StoryScaffold(
      step: _step,
      prompt: "Hi! I'm Sprout! I'll help you write your story. "
          'First — who is your story about?',
      sectionLabel: 'CHOOSE YOUR CHARACTER',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: StoryTheme.accentForStep(_step),
        onPressed: _selected == null ? null : _handleNext,
      ),
      child: StoryOptionGrid(
        options: StoryOptions.characters,
        selectedLabel: _selected,
        accent: StoryTheme.accentForStep(_step),
        onSelect: (label) => setState(() => _selected = label),
      ),
    );
  }
}
