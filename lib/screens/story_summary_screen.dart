import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 4 of 4 — review the three choices and start reading.
class StorySummaryScreen extends StatelessWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onStartReading;

  const StorySummaryScreen({
    super.key,
    required this.config,
    this.onBack,
    this.onStartReading,
  });

  static const int _step = 4;

  @override
  Widget build(BuildContext context) {
    return StoryScaffold(
      step: _step,
      prompt: 'Here is your story so far — ready to start reading?',
      sectionLabel: 'YOUR STORY',
      onBack: onBack,
      footer: StoryButton(
        label: 'Start Reading!',
        accent: StoryTheme.accentForStep(_step),
        showArrow: false,
        onPressed: () => onStartReading?.call(config),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryRow(
            caption: 'Character',
            option: StoryOptions.byLabel(
              StoryOptions.characters,
              config.character,
            ),
            accent: StoryTheme.accentCharacter,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            caption: 'Mood',
            option: StoryOptions.byLabel(StoryOptions.moods, config.mood),
            accent: StoryTheme.accentMood,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            caption: 'Setting',
            option: StoryOptions.byLabel(
              StoryOptions.settings,
              config.setting,
            ),
            accent: StoryTheme.accentSetting,
          ),
        ],
      ),
    );
  }
}

/// One reviewed choice. Renders the illustration for the option the child
/// actually picked; falls back to an em dash when nothing was chosen.
class _SummaryRow extends StatelessWidget {
  final String caption;
  final StoryOption? option;
  final Color accent;

  const _SummaryRow({
    required this.caption,
    required this.option,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final selected = option;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: StoryTheme.card,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: StoryTheme.hardShadow(),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            height: 40,
            child: selected == null
                ? null
                : SvgPicture.asset(selected.asset, width: 40, height: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              caption,
              style: StoryTheme.body(
                size: 14,
                color: StoryTheme.inkMuted,
                weight: 600,
              ),
            ),
          ),
          Text(
            selected?.label ?? '—',
            style: StoryTheme.display(size: 15, color: accent, weight: 600),
          ),
        ],
      ),
    );
  }
}
