import 'package:flutter/material.dart';

import 'story_theme.dart';

/// Primary action button for the story flow.
///
/// Cut out with the same ink line as the option stickers and sitting on the
/// same hard shadow, so pressing it looks like pressing a sticker flat against
/// the page: the shadow collapses and the button slides into its own shadow's
/// place. A null [onPressed] renders it disabled — the button stays laid out
/// either way, which keeps the step screens from jumping when a selection is
/// first made.
class StoryButton extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback? onPressed;
  final bool showArrow;

  /// False renders the quiet variant — paper fill instead of the action
  /// colour, with the same ink line.
  ///
  /// With one action colour for the whole flow, two solid buttons stacked
  /// together give no clue which one is the main way forward. Rank them.
  final bool filled;

  const StoryButton({
    super.key,
    required this.label,
    required this.accent,
    this.onPressed,
    this.showArrow = true,
    this.filled = true,
  });

  @override
  State<StoryButton> createState() => _StoryButtonState();
}

class _StoryButtonState extends State<StoryButton> {
  bool _held = false;

  bool get _enabled => widget.onPressed != null;

  Color _labelColor(StoryPalette palette) {
    if (!_enabled) return palette.inkMuted;
    // Dark ink on both fills. The old white-on-cyan label measured about
    // 2.1:1, which failed the 4.5:1 minimum on the flow's primary control.
    return widget.filled ? palette.onAction : palette.ink;
  }

  void _setHeld(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final down = _held && _enabled;
    final labelColor = _labelColor(palette);

    final Color fill;
    if (!_enabled) {
      fill = palette.disabled;
    } else if (widget.filled) {
      fill = widget.accent;
    } else {
      fill = palette.surface;
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      // Without this the child Text merges into this node and the label is
      // announced twice: "Next, Next, button".
      excludeSemantics: true,
      // excludeSemantics also drops the GestureDetector's tap action, so the
      // action has to be declared here or a screen reader can read the button
      // but never activate it. Null when disabled, so assistive tech does not
      // advertise a tap that would do nothing.
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setHeld(true) : null,
        onTapUp: _enabled ? (_) => _setHeld(false) : null,
        onTapCancel: _enabled ? () => _setHeld(false) : null,
        onTap: widget.onPressed,
        child: Transform.translate(
          offset: Offset(
            down ? StoryTheme.depth : 0,
            down ? StoryTheme.depth : 0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidth,
              ),
              boxShadow: palette.cardShadow(pressed: down),
            ),
            // Scales the label down rather than letting it overflow. "Create
            // Another Story" at this weight already outgrows a narrow phone,
            // and a child's device may be running a large text setting on top
            // of that — clipping the primary action is not an option.
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: StoryTheme.display(
                        size: 18,
                        color: labelColor,
                        weight: 700,
                        tracking: 0.3,
                      ),
                    ),
                    if (widget.showArrow) ...<Widget>[
                      const SizedBox(width: 9),
                      Icon(Icons.arrow_forward, color: labelColor, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
