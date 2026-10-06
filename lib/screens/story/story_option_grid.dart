import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'story_option.dart';
import 'story_theme.dart';

/// The 2x2 selectable option grid shared by the mood and place steps.
///
/// Each tile is a sticker: a saturated fill cut out with the heavy ink line,
/// sitting on a hard shadow and tipped a degree or two off square. The tilt is
/// what stops four rounded rectangles reading as a settings screen.
///
/// The tint is doing real work besides: now that every action is the one cyan,
/// the tints are what keep four options distinguishable at a glance.
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
      crossAxisSpacing: 13,
      mainAxisSpacing: 13,
      childAspectRatio: 1.42,
      children: <Widget>[
        for (var i = 0; i < options.length; i++)
          _StoryOptionTile(
            option: options[i],
            tintIndex: i,
            selected: options[i].label == selectedLabel,
            accent: accent,
            onTap: () => onSelect(options[i].label),
          ),
      ],
    );
  }
}

class _StoryOptionTile extends StatefulWidget {
  final StoryOption option;

  /// Position in the grid, which picks the tile's tint and its tilt.
  final int tintIndex;

  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _StoryOptionTile({
    required this.option,
    required this.tintIndex,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  /// How far each tile is tipped, in degrees.
  ///
  /// A fixed table rather than a random roll: a sticker that re-tilts whenever
  /// the grid rebuilds would be the animation the SRS rules out, and the
  /// alternating signs keep the grid from leaning as a whole.
  static const List<double> _tilts = <double>[-1.6, 1.4, 1.1, -1.2, 0.9];

  double get _tilt => _tilts[tintIndex % _tilts.length] * math.pi / 180;

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
    final palette = StoryTheme.of(context);
    final selected = widget.selected;
    final tint = palette.tintForIndex(widget.tintIndex);

    return Semantics(
      button: true,
      selected: selected,
      label: widget.option.label,
      // Without this the child Text merges into this node and the label is
      // announced twice ("Funny, Funny, selected, button"), and
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
        child: Transform.rotate(
          angle: widget._tilt,
          child: Transform.translate(
            offset: Offset(
              _held ? StoryTheme.depth : 0,
              _held ? StoryTheme.depth : 0,
            ),
            // The halo is always laid out, transparent when unselected, so
            // choosing a tile does not resize it and shuffle the grid.
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StoryTheme.radiusTile + 5),
                border: Border.all(
                  color: selected ? widget.accent : Colors.transparent,
                  width: StoryTheme.ringWidth,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
                  border: Border.all(
                    color: palette.outline,
                    width: StoryTheme.outlineWidth,
                  ),
                  boxShadow: palette.cardShadow(pressed: _held),
                ),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // The halo and the ink line together take 18px of
                          // height out of the tile, which is enough to push a
                          // fixed 62px illustration past the bottom edge on a
                          // 375x667 phone. The picture gives way first; the
                          // label is the part a child needs to read.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SvgPicture.asset(
                                widget.option.asset,
                                width: 62,
                                height: 62,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              widget.option.label,
                              textAlign: TextAlign.center,
                              style: StoryTheme.display(
                                size: 15.5,
                                color: palette.ink,
                                weight: selected ? 700 : 600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.outline,
                              width: StoryTheme.outlineWidthThin,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 13,
                            color: palette.onAction,
                          ),
                        ),
                      ),
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
