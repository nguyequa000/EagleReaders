import 'package:flutter/material.dart';

import 'story/story_theme.dart';

/// The "+5 coins!" toast shown when a quiz or story earns coins (CR #2).
///
/// Shown on the app's root ScaffoldMessenger, so it stays up over whichever
/// screen comes next (the reader after a quiz, the story after the wizard).
///
/// The bar itself is invisible; the toast is a yellow sticker drawn inside it,
/// so it takes its colours from the theme where it lands.
SnackBar coinsEarnedSnackBar(int coins) => SnackBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  // The sticker brings its own padding. Kept no taller than the plain bar it
  // replaced: it sits over the bottom of the screen, where the story flow's
  // Next button is, and swallows taps there while it shows.
  padding: EdgeInsets.zero,
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 2),
  content: _CoinsToast(coins: coins),
);

class _CoinsToast extends StatelessWidget {
  const _CoinsToast({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: palette.tintYellow,
        borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
        boxShadow: palette.cardShadow(depth: 3),
      ),
      child: Text(
        '🪙 +$coins coins!',
        textAlign: TextAlign.center,
        style: StoryTheme.display(size: 18, color: palette.ink, weight: 700),
      ),
    );
  }
}
