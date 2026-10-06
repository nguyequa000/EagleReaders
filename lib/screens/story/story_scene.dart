import 'dart:math';

import 'package:flutter/material.dart';

/// The kinds of shape a scene can be built from.
///
/// Deliberately a small vocabulary. Every place in the app is assembled from
/// these, which is what keeps a scene a short readable list instead of a page
/// of canvas maths.
enum SceneShape { hill, sun, cloud, tree, building, star, wave, planet, ring }

/// One thing drawn in a scene.
///
/// [x] and [y] are fractions of the box (0-1), so a scene describes itself
/// proportionally and survives being drawn at any size.
@immutable
class SceneElement {
  final SceneShape shape;
  final double x;
  final double y;
  final double scale;
  final Color color;

  const SceneElement(
    this.shape, {
    required this.x,
    required this.y,
    this.scale = 1,
    required this.color,
  });
}

/// A place the story can happen in.
///
/// Scenes are data, not drawing code: adding a tree is one more [SceneElement]
/// in the list, and re-colouring a whole place is editing the few colours at
/// the top. [StoryScenePainter] is the only thing that knows how to draw.
@immutable
class StoryScene {
  /// Matches the label in [StoryOptions.settings], which is how a chosen
  /// setting finds its scene.
  final String label;

  final Color skyTop;
  final Color skyBottom;
  final List<SceneElement> elements;

  const StoryScene({
    required this.label,
    required this.skyTop,
    required this.skyBottom,
    required this.elements,
  });

  /// The same place, in the light the story's mood casts.
  ///
  /// This is how step 3 shows its work. The hero's pose belongs to the child —
  /// they chose it on step 1, and a mood that silently restaged them would
  /// undo that — so the feeling changes the weather instead: spooky goes cold
  /// and dim, funny goes bright, calm goes soft, adventurous goes vivid.
  ///
  /// An unknown or unchosen mood returns the scene untouched rather than
  /// guessing, so the place a child picked is what they keep seeing.
  StoryScene forMood(String? mood) {
    final ({Color wash, double amount, double saturate}) light;
    switch (mood?.toLowerCase()) {
      case 'spooky':
        light = (wash: const Color(0xFF2B3A6B), amount: 0.34, saturate: 0.0);
      case 'funny':
        light = (wash: const Color(0xFFFFE27A), amount: 0.20, saturate: 0.0);
      case 'calm':
        light = (wash: const Color(0xFFE8D9F2), amount: 0.22, saturate: -0.18);
      case 'adventurous':
        light = (wash: const Color(0xFFFFB45C), amount: 0.16, saturate: 0.12);
      default:
        return this;
    }

    Color cast(Color c) {
      final washed = Color.lerp(c, light.wash, light.amount)!;
      if (light.saturate == 0) return washed;
      final hsl = HSLColor.fromColor(washed);
      return hsl
          .withSaturation((hsl.saturation + light.saturate).clamp(0.0, 1.0))
          .toColor();
    }

    return StoryScene(
      label: label,
      skyTop: cast(skyTop),
      skyBottom: cast(skyBottom),
      elements: <SceneElement>[
        for (final e in elements)
          SceneElement(
            e.shape,
            x: e.x,
            y: e.y,
            scale: e.scale,
            color: cast(e.color),
          ),
      ],
    );
  }

  /// The same scene at night.
  ///
  /// Rather than maintaining two colour sets per scene, dark mode blends every
  /// colour toward the dark ground. It reads as dusk, it cannot drift out of
  /// sync with the light version, and it keeps each scene a single list.
  StoryScene forDark(Color ground) {
    Color dim(Color c, double t) => Color.lerp(c, ground, t)!;
    return StoryScene(
      label: label,
      skyTop: dim(skyTop, 0.62),
      skyBottom: dim(skyBottom, 0.52),
      elements: <SceneElement>[
        for (final e in elements)
          SceneElement(
            e.shape,
            x: e.x,
            y: e.y,
            scale: e.scale,
            color: dim(e.color, 0.45),
          ),
      ],
    );
  }

  static const StoryScene forest = StoryScene(
    label: 'Forest',
    skyTop: Color(0xFF9ED8F0),
    skyBottom: Color(0xFFDFF4FC),
    elements: <SceneElement>[
      SceneElement(
        SceneShape.sun,
        x: 0.82,
        y: 0.18,
        scale: 1.1,
        color: Color(0xFFFFD23F),
      ),
      SceneElement(
        SceneShape.cloud,
        x: 0.24,
        y: 0.20,
        scale: 1.0,
        color: Color(0xFFFFFFFF),
      ),
      SceneElement(
        SceneShape.hill,
        x: 0.5,
        y: 0.70,
        scale: 1.15,
        color: Color(0xFF9BD98F),
      ),
      SceneElement(
        SceneShape.hill,
        x: 0.5,
        y: 0.84,
        scale: 1.0,
        color: Color(0xFF5FAE4B),
      ),
      SceneElement(
        SceneShape.tree,
        x: 0.13,
        y: 0.74,
        scale: 1.25,
        color: Color(0xFF2F7D32),
      ),
      SceneElement(
        SceneShape.tree,
        x: 0.33,
        y: 0.80,
        scale: 0.85,
        color: Color(0xFF3E9440),
      ),
      SceneElement(
        SceneShape.tree,
        x: 0.72,
        y: 0.77,
        scale: 1.05,
        color: Color(0xFF2F7D32),
      ),
      SceneElement(
        SceneShape.tree,
        x: 0.90,
        y: 0.83,
        scale: 0.8,
        color: Color(0xFF3E9440),
      ),
    ],
  );

  static const StoryScene ocean = StoryScene(
    label: 'Ocean',
    skyTop: Color(0xFF8FD6EE),
    skyBottom: Color(0xFFDCF3FA),
    elements: <SceneElement>[
      SceneElement(
        SceneShape.sun,
        x: 0.2,
        y: 0.17,
        scale: 1.0,
        color: Color(0xFFFFD23F),
      ),
      SceneElement(
        SceneShape.cloud,
        x: 0.74,
        y: 0.19,
        scale: 1.1,
        color: Color(0xFFFFFFFF),
      ),
      SceneElement(
        SceneShape.wave,
        x: 0.5,
        y: 0.62,
        scale: 1.0,
        color: Color(0xFF7FD4E6),
      ),
      SceneElement(
        SceneShape.wave,
        x: 0.5,
        y: 0.75,
        scale: 1.0,
        color: Color(0xFF35A6C4),
      ),
      SceneElement(
        SceneShape.wave,
        x: 0.5,
        y: 0.89,
        scale: 1.0,
        color: Color(0xFF17708C),
      ),
    ],
  );

  static const StoryScene city = StoryScene(
    label: 'City',
    skyTop: Color(0xFFC9BCEE),
    skyBottom: Color(0xFFFBE3EC),
    elements: <SceneElement>[
      SceneElement(
        SceneShape.sun,
        x: 0.86,
        y: 0.16,
        scale: 0.9,
        color: Color(0xFFFFD23F),
      ),
      SceneElement(
        SceneShape.building,
        x: 0.10,
        y: 0.78,
        scale: 1.25,
        color: Color(0xFFA99BDC),
      ),
      SceneElement(
        SceneShape.building,
        x: 0.28,
        y: 0.78,
        scale: 0.9,
        color: Color(0xFF6F5EAE),
      ),
      SceneElement(
        SceneShape.building,
        x: 0.45,
        y: 0.78,
        scale: 1.4,
        color: Color(0xFF8E7FC4),
      ),
      SceneElement(
        SceneShape.building,
        x: 0.63,
        y: 0.78,
        scale: 1.0,
        color: Color(0xFF6F5EAE),
      ),
      SceneElement(
        SceneShape.building,
        x: 0.82,
        y: 0.78,
        scale: 1.2,
        color: Color(0xFFA99BDC),
      ),
      SceneElement(
        SceneShape.hill,
        x: 0.5,
        y: 0.93,
        scale: 0.9,
        color: Color(0xFF4A4463),
      ),
    ],
  );

  static const StoryScene space = StoryScene(
    label: 'Outer Space',
    skyTop: Color(0xFF241F5C),
    skyBottom: Color(0xFF4A3C77),
    elements: <SceneElement>[
      SceneElement(
        SceneShape.star,
        x: 0.12,
        y: 0.16,
        scale: 1.0,
        color: Color(0xFFFFF0C2),
      ),
      SceneElement(
        SceneShape.star,
        x: 0.30,
        y: 0.09,
        scale: 0.7,
        color: Color(0xFFFFF0C2),
      ),
      SceneElement(
        SceneShape.star,
        x: 0.55,
        y: 0.20,
        scale: 0.8,
        color: Color(0xFFFFFFFF),
      ),
      SceneElement(
        SceneShape.star,
        x: 0.88,
        y: 0.13,
        scale: 1.0,
        color: Color(0xFFFFF0C2),
      ),
      SceneElement(
        SceneShape.star,
        x: 0.70,
        y: 0.33,
        scale: 0.6,
        color: Color(0xFFFFFFFF),
      ),
      SceneElement(
        SceneShape.planet,
        x: 0.80,
        y: 0.30,
        scale: 1.0,
        color: Color(0xFFC3A9F0),
      ),
      SceneElement(
        SceneShape.ring,
        x: 0.80,
        y: 0.30,
        scale: 1.0,
        color: Color(0xFFE0D3F7),
      ),
      SceneElement(
        SceneShape.hill,
        x: 0.5,
        y: 0.86,
        scale: 1.0,
        color: Color(0xFF5B4E86),
      ),
    ],
  );

  static const List<StoryScene> all = <StoryScene>[forest, ocean, city, space];

  /// The scene for a chosen setting label, or null when nothing is chosen yet.
  static StoryScene? forLabel(String? label) {
    if (label == null) return null;
    for (final scene in all) {
      if (scene.label == label) return scene;
    }
    return null;
  }
}

/// Draws a [StoryScene] as inked cut-out shapes. The only place that knows
/// what a "tree" looks like.
///
/// Every shape is filled and then cut out with [outline], the same heavy line
/// the option tiles and buttons use, so the preview belongs to the same drawn
/// world as the controls under it rather than looking like clip art dropped
/// into a window.
class StoryScenePainter extends CustomPainter {
  final StoryScene scene;

  /// The ink colour. Comes from the palette so the line flips to cream in dark
  /// mode along with every other outline in the flow.
  final Color outline;

  const StoryScenePainter(this.scene, {required this.outline});

  /// A deterministic value in -1..1 for a given seed.
  ///
  /// Used to take the mechanical precision off hand-drawn edges. It must be
  /// deterministic, not random: a hill that re-wobbles on every repaint would
  /// be the animation the SRS rules out.
  static double _wobble(int seed) {
    final v = sin(seed * 12.9898) * 43758.5453;
    return (v - v.floorToDouble()) * 2 - 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[scene.skyTop, scene.skyBottom],
        ).createShader(rect),
    );

    // The line thins down with the box so a 180px preview is not swallowed by
    // its own ink, and never gets so fine that the drawn look is lost.
    final strokeWidth = (size.shortestSide * 0.018).clamp(1.4, 3.2);

    for (var i = 0; i < scene.elements.length; i++) {
      _drawElement(canvas, size, scene.elements[i], strokeWidth, i);
    }
  }

  void _drawElement(
    Canvas canvas,
    Size size,
    SceneElement e,
    double strokeWidth,
    int index,
  ) {
    final fill = Paint()..color = e.color;
    final ink = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = e.x * size.width;
    final cy = e.y * size.height;
    // One unit derived from the box, so a scene keeps its proportions whether
    // it is drawn in a 200px preview or a full-width banner.
    final unit = size.shortestSide * 0.1 * e.scale;

    switch (e.shape) {
      case SceneShape.sun:
        canvas.drawCircle(Offset(cx, cy), unit * 0.85, fill);
        canvas.drawCircle(Offset(cx, cy), unit * 0.85, ink);

      case SceneShape.star:
        // Too small to carry a line; an outline here would just thicken it
        // into a blob.
        canvas.drawCircle(Offset(cx, cy), unit * 0.16, fill);

      case SceneShape.planet:
        canvas.drawCircle(Offset(cx, cy), unit * 0.95, fill);
        canvas.drawCircle(Offset(cx, cy), unit * 0.95, ink);

      case SceneShape.ring:
        final oval = Rect.fromCenter(
          center: Offset(cx, cy),
          width: unit * 3.2,
          height: unit * 0.7,
        );
        canvas.drawOval(oval, fill..color = e.color.withValues(alpha: 0.85));
        canvas.drawOval(oval, ink);

      case SceneShape.cloud:
        // Unioned into one silhouette rather than drawn as three overlapping
        // circles: stroking the circles separately would ink the seams where
        // they cross, which reads as a flower instead of a cloud.
        var merged = Path();
        for (final o in const <Offset>[
          Offset(-0.7, 0.05),
          Offset(0, -0.15),
          Offset(0.7, 0.05),
        ]) {
          final lobe = Path()
            ..addOval(
              Rect.fromCircle(
                center: Offset(cx + o.dx * unit * 1.4, cy + o.dy * unit * 1.4),
                radius: unit * 0.7,
              ),
            );
          merged = Path.combine(PathOperation.union, merged, lobe);
        }
        canvas.drawPath(merged, fill);
        canvas.drawPath(merged, ink);

      case SceneShape.hill:
        final path = Path()..moveTo(0, cy + _wobble(index) * unit * 0.08);
        const segments = 3;
        for (var i = 0; i < segments; i++) {
          final startX = size.width * (i / segments);
          final endX = size.width * ((i + 1) / segments);
          final lift = unit * (0.9 + _wobble(index * 31 + i) * 0.45);
          final endY = cy + _wobble(index * 17 + i) * unit * 0.22;
          path.quadraticBezierTo((startX + endX) / 2, cy - lift, endX, endY);
        }
        final crest = Path.from(path);
        path
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, fill);
        // Only the crest is inked. Running the line down the sides and across
        // the bottom would box the hill in and break the cut-out illusion.
        canvas.drawPath(crest, ink);

      case SceneShape.wave:
        final path = Path()..moveTo(0, cy);
        final step = size.width / 4;
        for (var i = 0; i < 4; i++) {
          path.quadraticBezierTo(
            step * i + step * 0.5,
            cy + (i.isEven ? -unit * 0.4 : unit * 0.4),
            step * (i + 1),
            cy,
          );
        }
        final crest = Path.from(path);
        path
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(crest, ink);

      case SceneShape.tree:
        final trunk = Rect.fromCenter(
          center: Offset(cx, cy + unit * 0.55),
          width: unit * 0.3,
          height: unit * 1.1,
        );
        canvas.drawRect(trunk, Paint()..color = const Color(0xFF8A5A33));
        canvas.drawRect(trunk, ink);
        // Back to front, so each tier's ink sits on top of the one behind it.
        for (var i = 2; i >= 0; i--) {
          final top = cy - unit * (1.6 - i * 0.5);
          final halfWidth = unit * (0.55 + i * 0.25);
          final bottom = top + unit * 0.85;
          final tier = Path()
            ..moveTo(cx + _wobble(index * 7 + i) * unit * 0.06, top)
            ..lineTo(cx - halfWidth, bottom)
            ..lineTo(cx + halfWidth, bottom)
            ..close();
          canvas.drawPath(tier, fill);
          canvas.drawPath(tier, ink);
        }

      case SceneShape.building:
        final height = unit * 2.6;
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - unit * 0.55, cy - height, unit * 1.1, height),
          const Radius.circular(3),
        );
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, ink);

        final windowFill = Paint()..color = const Color(0xFFFFD23F);
        final windowInk = Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.55;
        for (var row = 0; row < 3; row++) {
          for (var column = 0; column < 2; column++) {
            final window = Rect.fromLTWH(
              cx - unit * 0.34 + column * unit * 0.38,
              cy - height + unit * 0.32 + row * unit * 0.6,
              unit * 0.22,
              unit * 0.3,
            );
            canvas.drawRect(window, windowFill);
            canvas.drawRect(window, windowInk);
          }
        }
    }
  }

  @override
  bool shouldRepaint(StoryScenePainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.outline != outline;
}
