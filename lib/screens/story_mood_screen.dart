import 'package:flutter/material.dart';

import 'story/hero_preview.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_option_grid.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 2 of 4 — mood selection.
///
/// The preview is not decoration here. The mood decides the hero's face, so
/// tapping "Spooky" widens their eyes on the spot — the choice shows its own
/// consequence instead of being a label the child takes on trust.
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
      sectionLabel: 'CHOOSE A MOOD',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: StoryTheme.accentForStep(_step),
        onPressed: _selected == null ? null : _handleNext,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HeroPreview(
            hero: widget.config.hero,
            height: 224,
            mood: _selected,
          ),
          const SizedBox(height: 18),
          StoryOptionGrid(
            options: StoryOptions.moods,
            selectedLabel: _selected,
            accent: StoryTheme.accentForStep(_step),
            onSelect: (label) => setState(() => _selected = label),
          ),
        ],
      ),
    );
  }
}
