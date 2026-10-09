import 'package:flutter/material.dart';

import 'story/hero_preview.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_row_label.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 3 of 4 — how the story feels.
///
/// The preview is not decoration here. The mood decides the hero's face, so
/// tapping "Spooky" widens their eyes on the spot — the choice shows its own
/// consequence instead of being a label the child takes on trust.
class StoryMoodScreen extends StatefulWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  /// The feelings on offer. The flow leaves out Spooky for the youngest
  /// readers (Parent Settings → Age Restrictions).
  final List<StoryOption> options;

  const StoryMoodScreen({
    super.key,
    required this.config,
    this.onBack,
    this.onNext,
    this.options = StoryOptions.moods,
  });

  @override
  State<StoryMoodScreen> createState() => _StoryMoodScreenState();
}

class _StoryMoodScreenState extends State<StoryMoodScreen> {
  static const int _step = 3;

  /// Seeded from the incoming config so stepping Back re-enters the screen
  /// with the child's existing choice still highlighted and Next still live.
  /// A feeling no longer on offer is dropped rather than kept selected.
  late String? _selected =
      widget.options.any((option) => option.label == widget.config.mood)
      ? widget.config.mood
      : null;

  void _handleNext() {
    final selected = _selected;
    if (selected == null) return;
    widget.onNext?.call(widget.config.copyWith(mood: selected));
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return StoryScaffold(
      step: _step,
      title: 'Pick a feeling!',
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
            setting: widget.config.setting,
            mood: _selected,
          ),
          const SizedBox(height: 12),
          const StoryRowLabel(text: 'CHOOSE A MOOD'),
          const SizedBox(height: 10),
          StoryOptionGrid(
            options: widget.options,
            selectedLabel: _selected,
            accent: palette.action,
            onSelect: (label) => setState(() => _selected = label),
          ),
        ],
      ),
    );
  }
}
