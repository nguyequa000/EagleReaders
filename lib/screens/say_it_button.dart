import 'dart:math';

import 'package:flutter/material.dart';

import 'sticker_kit.dart';
import 'story/story_theme.dart';

/// The "🔊 Say it" pill that pops up by a word the child highlighted in the
/// book reader; tapping it speaks the word.
class SayItButton extends StatelessWidget {
  const SayItButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _gap = 8.0;

  /// Where a [button] of that size goes for a [selection] inside a [view]
  /// (all in the view's coordinates): centred just above the word, or just
  /// below it when the word is on the top line, and always fully inside the
  /// view so a word at the edge still gets a reachable button.
  static Offset place(Rect selection, Size view, Size button) {
    final aboveTop = selection.top - _gap - button.height;
    final top = aboveTop >= _gap ? aboveTop : selection.bottom + _gap;
    final left = selection.center.dx - button.width / 2;
    return Offset(
      left.clamp(_gap, max(_gap, view.width - button.width - _gap)),
      top.clamp(_gap, max(_gap, view.height - button.height - _gap)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Semantics(
      button: true,
      label: 'Say this word',
      excludeSemantics: true,
      child: StickerPill(
        key: const Key('say-it'),
        color: palette.tintYellow,
        onTap: onTap,
        child: Text(
          '🔊 Say it',
          style: StoryTheme.display(size: 16, color: palette.ink),
        ),
      ),
    );
  }
}

/// Fills the reader's page and puts a [SayItButton] by the highlighted
/// [selection] (in the page's coordinates), placed by its real size.
class SayItPopup extends StatelessWidget {
  const SayItPopup({super.key, required this.selection, required this.onTap});

  final Rect selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    delegate: _SayItLayout(selection),
    child: SayItButton(onTap: onTap),
  );
}

class _SayItLayout extends SingleChildLayoutDelegate {
  _SayItLayout(this.selection);

  final Rect selection;

  // No height limit: the pill's tap target centres itself in whatever
  // height it gets, so a bounded one would stretch it over the whole page.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      SayItButton.place(selection, size, childSize);

  @override
  bool shouldRelayout(_SayItLayout old) => old.selection != selection;
}
