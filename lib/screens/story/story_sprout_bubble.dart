import 'package:flutter/material.dart';

import 'story_theme.dart';

/// Sprout's speech bubble. The avatar keeps the mascot emoji deliberately —
/// Sprout is a character, not an option, so it is not part of the illustrated
/// option set.
class StorySproutBubble extends StatelessWidget {
  final String message;
  final Color accent;

  const StorySproutBubble({
    super.key,
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: palette.outline,
              width: StoryTheme.outlineWidth,
            ),
            boxShadow: palette.cardShadow(depth: 3),
          ),
          child: const Center(
            child: Text('🌱', style: TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(StoryTheme.radiusTile),
                bottomLeft: Radius.circular(StoryTheme.radiusTile),
                bottomRight: Radius.circular(StoryTheme.radiusTile),
              ),
              boxShadow: palette.cardShadow(depth: 3),
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidthThin,
              ),
            ),
            child: Text(
              message,
              style: StoryTheme.body(size: 15, color: palette.ink, weight: 500),
            ),
          ),
        ),
      ],
    );
  }
}
