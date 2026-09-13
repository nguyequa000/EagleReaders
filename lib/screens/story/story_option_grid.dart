import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'story_option.dart';
import 'story_theme.dart';

/// The 2x2 selectable option grid shared by steps 1-3.
class StoryOptionGrid extends StatelessWidget {
  final List<StoryOption> options;
  final String? selectedLabel;
  final Color accent;
  final ValueChanged<String> onSelect;

  const StoryOptionGrid({
    super.key,
    required this.options,
    required this.selectedLabel,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 0.92,
      children: options
          .map((option) => _StoryOptionTile(
                option: option,
                selected: option.label == selectedLabel,
                accent: accent,
                onTap: () => onSelect(option.label),
              ))
          .toList(),
    );
  }
}

class _StoryOptionTile extends StatefulWidget {
  final StoryOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _StoryOptionTile({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_StoryOptionTile> createState() => _StoryOptionTileState();
}

class _StoryOptionTileState extends State<_StoryOptionTile> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.option.label,
      // Without this the child Text merges into this node and the label is
      // announced twice ("Brave Knight, Brave Knight, selected, button"), and
      // the SvgPicture contributes a stray isImage flag. The tile is a button.
      excludeSemantics: true,
      // excludeSemantics also drops the GestureDetector's tap action, so the
      // action has to be declared here or a screen reader can read the tile
      // but never select it.
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        onTap: widget.onTap,
        child: Transform.translate(
          offset: Offset(0, _held ? StoryTheme.depth : 0),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(
                      widget.accent.withValues(alpha: 0.12),
                      StoryTheme.card,
                    )
                  : StoryTheme.card,
              borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
              border: Border.all(
                color: selected ? widget.accent : StoryTheme.shadow,
                width: selected ? StoryTheme.ringWidth : 1,
              ),
              boxShadow: StoryTheme.hardShadow(pressed: _held),
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SvgPicture.asset(
                        widget.option.asset,
                        width: 64,
                        height: 64,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          widget.option.label,
                          textAlign: TextAlign.center,
                          style: StoryTheme.display(
                            size: 15,
                            color: selected ? widget.accent : StoryTheme.ink,
                            weight: selected ? 600 : 500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
