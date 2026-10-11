import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';
import 'story/story_theme_controller.dart';

/// The sticker-book pieces the story flow draws with, for the screens outside
/// it: login, the persona and name pickers, the PIN screens, the child
/// dashboard and the quiz.
///
/// The look itself — the palette, the ink line, the hard shadow, the button —
/// is the story flow's own ([StoryTheme], [StoryButton]); this file only adds
/// the shapes those screens need that the flow keeps private.

/// How far the [index]th sticker in a row or grid is tipped, in radians.
///
/// The same fixed table the story flow's option grid uses, so a dashboard card
/// leans the way a story tile does, and never re-tilts when the screen
/// rebuilds. The alternating signs keep a row from leaning as a whole.
double stickerTilt(int index) => _tilts[index % _tilts.length] * math.pi / 180;

const List<double> _tilts = <double>[-1.6, 1.4, 1.1, -1.2, 0.9];

/// A shape cut out with the ink line and sitting on a hard shadow, optionally
/// tipped off square and optionally pressable.
///
/// Pressing slides it into its shadow's place, the way the story tiles do. The
/// child is clipped inside the ink line, so a book cover fills the card without
/// painting over its edge.
class StickerCard extends StatefulWidget {
  final Widget child;

  /// The fill; the paper [StoryPalette.surface] when null.
  final Color? color;

  /// Radians; see [stickerTilt].
  final double tilt;

  final VoidCallback? onTap;

  /// What a screen reader announces for a tappable card. Null leaves the
  /// card's own text to speak for it.
  final String? semanticLabel;

  final double radius;
  final EdgeInsetsGeometry padding;
  final double depth;

  /// Draws the action-coloured halo the story tiles use for a selection. The
  /// halo's room is always laid out, so selecting does not resize the card.
  final bool? selected;

  const StickerCard({
    super.key,
    required this.child,
    this.color,
    this.tilt = 0,
    this.onTap,
    this.semanticLabel,
    this.radius = StoryTheme.radiusTile,
    this.padding = EdgeInsets.zero,
    this.depth = StoryTheme.depth,
    this.selected,
  });

  @override
  State<StickerCard> createState() => _StickerCardState();
}

class _StickerCardState extends State<StickerCard> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final tappable = widget.onTap != null;
    final down = _held && tappable;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color ?? palette.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
        boxShadow: palette.cardShadow(pressed: down, depth: widget.depth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StoryTheme.outlineWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.radius - StoryTheme.outlineWidth,
          ),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (widget.selected != null) {
      card = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 5),
          border: Border.all(
            color: widget.selected! ? palette.action : Colors.transparent,
            width: StoryTheme.ringWidth,
          ),
        ),
        child: card,
      );
    }

    card = Transform.rotate(
      angle: widget.tilt,
      child: Transform.translate(
        offset: Offset(down ? widget.depth : 0, down ? widget.depth : 0),
        child: card,
      ),
    );

    if (!tappable) return card;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      // With a label of its own, the card's text would otherwise be read out
      // after it a second time. excludeSemantics also drops the gesture's tap
      // action, hence onTap here too.
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}

/// The band across the top of a sticker-book screen, cut off from the page
/// with the ink line — the same header the story steps have. Yellow on the
/// child's screens, pink on the grown-ups'.
class StickerHeader extends StatelessWidget {
  final String title;

  /// Shows a back sticker; [onBack] defaults to popping the route.
  final bool showBack;
  final VoidCallback? onBack;

  final List<Widget> trailing;

  /// Draws the parent band ([StoryPalette.headerParent]) instead of the
  /// child's.
  final bool forParent;

  const StickerHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
    this.trailing = const <Widget>[],
    this.forParent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: forParent ? palette.headerParent : palette.header,
        border: Border(
          bottom: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 11,
        left: showBack ? 14 : 20,
        right: 16,
      ),
      child: Row(
        children: <Widget>[
          if (showBack)
            StickerIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: showBack ? 8 : 0),
              // A long chapter title or child's name shrinks rather than
              // pushing the stickers off the band.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: showBack ? Alignment.center : Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: StoryTheme.display(
                    size: 21,
                    color: forParent
                        ? palette.headerParentInk
                        : palette.headerInk,
                    weight: 700,
                    tracking: 0.2,
                  ),
                ),
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// A round sticker with an icon on it: 42px drawn inside a 48dp target, so
/// the shape stays chunky without the hit area dropping under the minimum.
class StickerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// The fill; paper when null.
  final Color? color;

  const StickerIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color ?? palette.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
          boxShadow: palette.cardShadow(depth: 3),
        ),
        child: Icon(icon, color: palette.ink, size: 21),
      ),
    );
  }
}

/// Switches between day, night and following the device, like the sticker in
/// the story flow's header.
class ThemeSticker extends StatelessWidget {
  const ThemeSticker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: storyThemeController,
      builder: (context, mode, _) => StickerIconButton(
        icon: storyThemeController.icon,
        tooltip: storyThemeController.label,
        onTap: storyThemeController.next,
      ),
    );
  }
}

/// A small rounded tag with the ink line: the coin balance, "Skip", a section
/// title. Tappable ones keep a 48dp-tall target around the drawn pill.
class StickerPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// The fill; paper when null.
  final Color? color;

  /// Radians; see [stickerTilt].
  final double tilt;

  const StickerPill({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.tilt = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final Widget pill = Transform.rotate(
      angle: tilt,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color ?? palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidthThin,
          ),
          boxShadow: palette.cardShadow(depth: 3),
        ),
        child: child,
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// A text field drawn as a paper sticker: ink edge, action-coloured when
/// focused.
InputDecoration stickerInputDecoration(
  StoryPalette palette, {
  String? hint,
  String? label,
  IconData? icon,
  String? errorText,
  String? counterText,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
    borderSide: BorderSide(color: color, width: StoryTheme.outlineWidth),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    errorText: errorText,
    counterText: counterText,
    filled: true,
    fillColor: palette.surface,
    hintStyle: StoryTheme.body(color: palette.inkMuted),
    labelStyle: StoryTheme.body(color: palette.inkMuted),
    prefixIcon: icon == null ? null : Icon(icon, color: palette.ink),
    border: border(palette.outline),
    enabledBorder: border(palette.outline),
    focusedBorder: border(palette.action),
    errorBorder: border(palette.tintCoral),
    focusedErrorBorder: border(palette.tintCoral),
  );
}

/// Wraps a text field in the hard sticker shadow. For fields with no error
/// or counter line under them — the shadow would sit under that line too.
class StickerFieldShadow extends StatelessWidget {
  final Widget child;

  const StickerFieldShadow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
        boxShadow: palette.cardShadow(depth: 3),
      ),
      child: child,
    );
  }
}

/// A sticker-book screen laid out like login: the header band, then an
/// emoji on a round sticker and a prompt on a crooked tag, with [children]
/// under them, all centred and scrollable. The persona picker, the name
/// picker and the PIN screens are all this shape.
class StickerPromptPage extends StatelessWidget {
  final String title;
  final String emoji;

  /// The fill behind [emoji].
  final Color emojiTint;

  final String prompt;

  /// A smaller line under the prompt tag.
  final String? caption;

  final List<Widget> children;

  /// Shows the header's back sticker when the route can pop. False for a
  /// screen that is the start of the app once signed in.
  final bool allowBack;

  /// Draws the parent's pink header band; see [StickerHeader.forParent].
  final bool forParent;

  const StickerPromptPage({
    super.key,
    required this.title,
    required this.emoji,
    required this.emojiTint,
    required this.prompt,
    this.caption,
    this.children = const <Widget>[],
    this.allowBack = true,
    this.forParent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      body: PaperBackground(
        child: Column(
          children: [
            StickerHeader(
              title: title,
              // Opened straight after sign-in there is nothing to go back to.
              showBack: allowBack && Navigator.of(context).canPop(),
              trailing: const [ThemeSticker()],
              forParent: forParent,
            ),
            // Scrollable so it still fits with the keyboard up, or with a
            // long list of children.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPrompt(palette),
                          if (caption != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              caption!,
                              textAlign: TextAlign.center,
                              style: StoryTheme.body(color: palette.inkMuted),
                            ),
                          ],
                          const SizedBox(height: 32),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt(StoryPalette palette) {
    return Column(
      children: [
        Transform.rotate(
          angle: stickerTilt(0),
          child: StickerEmoji(emoji: emoji, color: emojiTint, size: 104),
        ),
        const SizedBox(height: 20),
        StickerCard(
          color: palette.tintYellow,
          tilt: stickerTilt(1),
          radius: StoryTheme.radiusButton,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            prompt,
            textAlign: TextAlign.center,
            style: StoryTheme.display(
              size: 24,
              color: palette.ink,
              weight: 700,
            ),
          ),
        ),
      ],
    );
  }
}

/// An emoji on a round tinted sticker with the ink line.
class StickerEmoji extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;

  const StickerEmoji({
    super.key,
    required this.emoji,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
        // The big one sits on the full shadow, like a tile; small ones on
        // the shallow shadow the pills use.
        boxShadow: palette.cardShadow(depth: size >= 80 ? StoryTheme.depth : 3),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
      ),
    );
  }
}

/// One choice in a list of who's who: an emoji sticker, a name and an arrow
/// on a paper card, tipped like the story tiles.
class StickerChoiceCard extends StatelessWidget {
  final String emoji;
  final String label;

  /// The fill behind [emoji].
  final Color tint;

  /// Position in the list, which picks the tilt; see [stickerTilt].
  final int index;

  final VoidCallback onTap;

  const StickerChoiceCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.tint,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      // Past the two the prompt uses, so the first card doesn't lean the
      // same way as the tag right above it.
      tilt: stickerTilt(index + 2),
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          StickerEmoji(emoji: emoji, color: tint),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StoryTheme.display(
                size: 22,
                color: palette.ink,
                weight: 700,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: palette.ink, size: 26),
        ],
      ),
    );
  }
}

/// A PIN screen: the prompt page with the PIN field and one button under it.
/// The parent and child PIN screens differ only in their words and colours.
class StickerPinPage extends StatelessWidget {
  final String title;
  final String emoji;

  /// The fill behind [emoji].
  final Color emojiTint;

  final String prompt;
  final TextEditingController controller;

  /// Shown on a coral card under the field rather than as the field's own
  /// error line, so the field's hard shadow stays the field's size.
  final String? error;

  final String buttonLabel;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;

  /// Draws the parent's pink header band; see [StickerHeader.forParent].
  final bool forParent;

  const StickerPinPage({
    super.key,
    required this.title,
    required this.emoji,
    required this.emojiTint,
    required this.prompt,
    required this.controller,
    required this.buttonLabel,
    required this.onSubmit,
    this.error,
    this.onChanged,
    this.forParent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerPromptPage(
      title: title,
      emoji: emoji,
      emojiTint: emojiTint,
      prompt: prompt,
      forParent: forParent,
      children: [
        StickerFieldShadow(
          child: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: StoryTheme.display(
              size: 32,
              color: palette.ink,
              weight: 700,
              tracking: 16,
            ),
            decoration: stickerInputDecoration(palette, counterText: ''),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          StickerCard(
            color: palette.tintCoral,
            radius: StoryTheme.radiusButton,
            depth: 3,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: StoryTheme.body(color: palette.ink, weight: 700),
            ),
          ),
        ],
        const SizedBox(height: 24),
        StoryButton(
          label: buttonLabel,
          accent: palette.action,
          showArrow: false,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

/// A whole sticker-book screen: the paper, the header band and [body] under
/// it. For the list-shaped screens; prompt-shaped ones use
/// [StickerPromptPage].
class StickerPage extends StatelessWidget {
  final String title;
  final Widget body;

  /// Draws the parent's pink header band; see [StickerHeader.forParent].
  final bool forParent;

  /// Shows the header's back sticker when the route can pop.
  final bool allowBack;

  /// Stickers at the right of the header; the day/night switch always ends
  /// the row.
  final List<Widget> actions;

  final Widget? floatingActionButton;

  const StickerPage({
    super.key,
    required this.title,
    required this.body,
    this.forParent = false,
    this.allowBack = true,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      floatingActionButton: floatingActionButton,
      body: PaperBackground(
        child: Column(
          children: [
            StickerHeader(
              title: title,
              showBack: allowBack && Navigator.of(context).canPop(),
              forParent: forParent,
              trailing: [...actions, const ThemeSticker()],
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The bold title over a group of cards: "Reading Stats", "Child Profiles".
class StickerSectionTitle extends StatelessWidget {
  final String text;

  const StickerSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: StoryTheme.display(
          size: 19,
          color: StoryTheme.of(context).ink,
          weight: 700,
        ),
      ),
    );
  }
}

/// An icon on a round tinted sticker with the ink line — the leading mark on
/// a row, where the child screens put an emoji.
class StickerIconDisc extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const StickerIconDisc({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidthThin,
        ),
      ),
      child: Icon(icon, color: palette.ink, size: size * 0.5),
    );
  }
}

/// One tappable line on a paper card: a leading mark, a title, an optional
/// line under it and an arrow. Square, not tipped — these are the parent's
/// lists, which want to scan as a column.
class StickerRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the arrow; null keeps the arrow when [onTap] is set.
  final Widget? trailing;

  const StickerRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      onTap: onTap,
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: StoryTheme.display(
                    size: 17,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: StoryTheme.body(
                      size: 13,
                      color: palette.inkMuted,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : Icon(Icons.chevron_right, color: palette.ink)),
        ],
      ),
    );
  }
}

/// Something went wrong, said on a coral card rather than in red text, so it
/// reads in both modes and sits in the same world as everything else.
class StickerErrorNote extends StatelessWidget {
  final String message;

  const StickerErrorNote(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      color: palette.tintCoral,
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        message,
        style: StoryTheme.body(color: palette.ink, weight: 700),
      ),
    );
  }
}
