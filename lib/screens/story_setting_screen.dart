import 'package:flutter/material.dart';

import 'story/hero_preview.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_row_label.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 2 of 4 — where the story happens.
///
/// Ahead of the feeling step on purpose: the place is the backdrop every
/// later preview draws, so choosing it first means the child never looks at
/// an empty box.
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
  static const int _step = 2;

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
    final palette = StoryTheme.of(context);

    return StoryScaffold(
      step: _step,
      title: 'Pick a place!',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: palette.action,
        onPressed: _selected == null ? null : _handleNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HeroPreview(
            hero: widget.config.hero,
            height: HeroPreview.heightFor(
              context,
              fraction: 0.21,
              min: 150,
              max: 230,
            ),
            setting: _selected,
            mood: widget.config.mood,
          ),
          const SizedBox(height: 12),
          const StoryRowLabel(text: 'CHOOSE A PLACE'),
          const SizedBox(height: 10),
          StoryOptionGrid(
            options: StoryOptions.settings,
            selectedLabel: _selected,
            accent: palette.action,
            onSelect: (label) => setState(() => _selected = label),
          ),
        ],
      ),
    );
  }
}
