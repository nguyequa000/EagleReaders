import 'package:flutter/material.dart';

import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// How the child wants to write their story.
enum WriterLevel {
  /// Sprout writes the story from the child's picks (the AI reader).
  beginning,

  /// The child writes it; Sprout only offers idea questions.
  advanced,
}

/// Shown after the summary's "Start Reading!": Beginning or Advanced writer.
///
/// Its own screen rather than a change to the summary, so the four steps
/// before it stay exactly as they are. The progress bar stays full: the
/// building is done, this only picks how the story gets written.
class StoryModeScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final ValueChanged<WriterLevel> onChoose;

  const StoryModeScreen({super.key, this.onBack, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return StoryScaffold(
      step: 4,
      title: 'How do you want to write?',
      prompt: 'Do you want me to help, or do you want to write it yourself?',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LevelCard(
            title: 'Beginning writer',
            caption: 'Sprout writes the story with you.',
            icon: Icons.auto_stories,
            tint: palette.tintForIndex(1),
            onTap: () => onChoose(WriterLevel.beginning),
          ),
          const SizedBox(height: 16),
          _LevelCard(
            title: 'Advanced writer',
            caption: 'You write the story. Sprout gives ideas.',
            icon: Icons.edit,
            tint: palette.tintForIndex(0),
            onTap: () => onChoose(WriterLevel.advanced),
          ),
        ],
      ),
    );
  }
}

/// One big choice, cut out like the option stickers on the steps before it.
class _LevelCard extends StatefulWidget {
  final String title;
  final String caption;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _LevelCard({
    required this.title,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held != value) setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.caption}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          // Presses flat into its own shadow, like StoryButton.
          transform: Matrix4.translationValues(
            _held ? StoryTheme.depth : 0,
            _held ? StoryTheme.depth : 0,
            0,
          ),
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: widget.tint,
            borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
            border: Border.all(
              color: palette.outline,
              width: StoryTheme.outlineWidth,
            ),
            boxShadow: palette.cardShadow(pressed: _held),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.outline,
                    width: StoryTheme.outlineWidthThin,
                  ),
                ),
                child: Icon(widget.icon, size: 28, color: palette.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.title,
                      style: StoryTheme.display(
                        size: 20,
                        color: palette.ink,
                        weight: 700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.caption,
                      style: StoryTheme.body(size: 15, color: palette.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
