import 'package:flutter/material.dart';
import 'parent_pin_screen.dart';
import 'child_selector_screen.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

class ParentOrChildScreen extends StatelessWidget {
  const ParentOrChildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerPromptPage(
      title: 'Story Sprout',
      emoji: '🌱',
      emojiTint: palette.tintGreen,
      prompt: 'Who is reading today?',
      // The first screen once signed in.
      allowBack: false,
      children: [
        StickerChoiceCard(
          index: 0,
          emoji: '👨‍👩‍👧',
          label: 'Parent',
          tint: palette.tintGreen,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ParentPinScreen())),
        ),
        const SizedBox(height: 20),
        StickerChoiceCard(
          index: 1,
          emoji: '🧒',
          label: 'Child',
          tint: palette.tintYellow,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChildSelectorScreen()),
          ),
        ),
      ],
    );
  }
}
