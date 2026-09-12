import 'package:flutter/material.dart';

import 'story_theme.dart';

/// Primary action button for the story flow.
///
/// Carries a hard offset shadow that collapses on press, so the button appears
/// to physically depress. A null [onPressed] renders it disabled — the button
/// stays laid out either way, which keeps the step screens from jumping when a
/// selection is first made.
class StoryButton extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback? onPressed;
  final bool showArrow;

  const StoryButton({
    super.key,
    required this.label,
    required this.accent,
    this.onPressed,
    this.showArrow = true,
  });

  @override
  State<StoryButton> createState() => _StoryButtonState();
}

class _StoryButtonState extends State<StoryButton> {
  bool _held = false;

  bool get _enabled => widget.onPressed != null;

  void _setHeld(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final down = _held && _enabled;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      // Without this the child Text merges into this node and the label is
      // announced twice: "Next, Next, button".
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setHeld(true) : null,
        onTapUp: _enabled ? (_) => _setHeld(false) : null,
        onTapCancel: _enabled ? () => _setHeld(false) : null,
        onTap: widget.onPressed,
        child: Transform.translate(
          offset: Offset(0, down ? StoryTheme.depth : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _enabled ? widget.accent : StoryTheme.disabled,
              borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
              boxShadow: StoryTheme.hardShadow(pressed: down),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  widget.label,
                  style: StoryTheme.display(
                    size: 16,
                    color: Colors.white,
                    weight: 600,
                    tracking: 0.5,
                  ),
                ),
                if (widget.showArrow) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
