import 'package:flutter/material.dart';

import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 3 of 4 — setting selection.
class StorySettingScreen extends StatefulWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  const StorySettingScreen({
    super.key,
    required this.config,
    this.onBack,
    this.onNext,
  });

  @override
  State<StorySettingScreen> createState() => _StorySettingScreenState();
}

class _StorySettingScreenState extends State<StorySettingScreen> {
  static const int _step = 3;

  /// Seeded from the incoming config so stepping Back re-enters the screen
  /// with the child's existing choice still highlighted and Next still live.
  late String? _selected = widget.config.setting;

  void _handleNext() {
    final selected = _selected;
    if (selected == null) return;
    widget.onNext?.call(widget.config.copyWith(setting: selected));
  }

  @override
  Widget build(BuildContext context) {
    return StoryScaffold(
      step: _step,
      prompt: 'Nice! Now, where does your story take place?',
      sectionLabel: 'CHOOSE A SETTING',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: StoryTheme.accentForStep(_step),
        onPressed: _selected == null ? null : _handleNext,
      ),
      child: StoryOptionGrid(
        options: StoryOptions.settings,
        selectedLabel: _selected,
        accent: StoryTheme.accentForStep(_step),
        onSelect: (label) => setState(() => _selected = label),
      ),
    );
  }
}
