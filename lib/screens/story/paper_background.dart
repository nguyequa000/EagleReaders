import 'dart:math';

import 'package:flutter/material.dart';

import 'story_theme.dart';

/// The speckled sheet every story step is drawn on.
///
/// The flecks are generated once into a fixed 120x120 tile and then repeated,
/// rather than scattered across the whole canvas. Two reasons: the pattern
/// cannot shift when the widget is resized or the keyboard opens, and the cost
/// does not grow with screen size.
///
/// Deliberately near-invisible. It is there to stop a large flat fill reading
/// as a blank screen, not to be noticed — the SRS rules out visual
/// distraction, and a child picking a story should be looking at the hero.
class PaperBackground extends StatelessWidget {
  final Widget child;

  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          // The flecks never change, so they are painted once and kept out of
          // the repaint of everything layered over them.
          child: RepaintBoundary(
            child: CustomPaint(painter: PaperPainter(palette)),
          ),
        ),
        child,
      ],
    );
  }
}

/// One fleck in the paper tile.
@immutable
class _Fleck {
  final double x;
  final double y;
  final double radius;
  final double opacity;

  const _Fleck(this.x, this.y, this.radius, this.opacity);
}

/// Paints [PaperBackground]'s ground and speckle.
class PaperPainter extends CustomPainter {
  final StoryPalette palette;

  const PaperPainter(this.palette);

  /// Side of the repeating tile, in logical pixels.
  static const double tile = 120;

  /// The tile's flecks, generated once for the life of the process.
  ///
  /// A fixed seed rather than a random one: the paper has to look the same on
  /// every screen and every launch, or the texture becomes the distraction it
  /// exists to avoid.
  static final List<_Fleck> _flecks = _generate();

  static List<_Fleck> _generate() {
    final rng = Random(20260401);
    return <_Fleck>[
      for (var i = 0; i < 26; i++)
        _Fleck(
          rng.nextDouble() * tile,
          rng.nextDouble() * tile,
          0.6 + rng.nextDouble() * 1.1,
          0.25 + rng.nextDouble() * 0.45,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.ground);

    final columns = (size.width / tile).ceil();
    final rows = (size.height / tile).ceil();
    final paint = Paint();

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final originX = column * tile;
        final originY = row * tile;
        for (final fleck in _flecks) {
          paint.color = palette.paperFleck.withValues(alpha: fleck.opacity);
          canvas.drawCircle(
            Offset(originX + fleck.x, originY + fleck.y),
            fleck.radius,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
