import 'package:flutter/material.dart';

import 'hero_config.dart';
import 'story_scene.dart';
import 'story_theme.dart';

/// The big preview box that sits across the top half of every step.
///
/// Framed as the largest sticker on the page — the heaviest ink line and the
/// deepest shadow in the flow — because it is the thing the child is actually
/// reacting to and everything underneath it is a control for changing it.
class HeroPreview extends StatelessWidget {
  final HeroConfig hero;

  /// Height of the box. The builder gives it less room than the later steps,
  /// because it has control rows to fit underneath.
  final double height;

  /// The chosen place, drawn behind the hero.
  ///
  /// Null until a place has been picked, which renders the undrawn sheet. This
  /// is why choosing the place comes before choosing the feeling: with the
  /// order reversed the child spends a whole step looking at a blank box.
  final String? setting;

  /// The story's mood, which shifts the light in the scene.
  ///
  /// The hero's own pose is the child's choice and is left alone — a mood that
  /// silently restaged the hero would undo a decision they made on step 1.
  /// The weather is the story's to change.
  final String? mood;

  const HeroPreview({
    super.key,
    required this.hero,
    this.height = 260,
    this.setting,
    this.mood,
  });

  /// The preview's height on this screen, as a fraction of it.
  ///
  /// Fixed heights cannot do this job: the value that fills a 900px window
  /// leaves a short phone scrolling, and the value that fits the short phone
  /// strands a hundred points of dead space on the tall one. The clamps are
  /// what keep the box from collapsing on a very small screen or swallowing a
  /// tablet.
  static double heightFor(
    BuildContext context, {
    required double fraction,
    required double min,
    required double max,
  }) {
    return (MediaQuery.sizeOf(context).height * fraction).clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final pet = hero.petAsset;

    var scene = StoryScene.forLabel(setting);
    if (scene != null) {
      scene = scene.forMood(mood);
      if (palette.isDark) scene = scene.forDark(palette.ground);
    }

    return Semantics(
      excludeSemantics: true,
      label: <String>[
        hero.name == null ? 'Your hero' : 'Your hero, ${hero.name}',
        if (setting != null) 'in $setting',
        if (mood != null) 'feeling $mood',
      ].join(', '),
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
          boxShadow: palette.cardShadow(depth: 6),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: scene != null
                  ? CustomPaint(
                      painter: StoryScenePainter(
                        scene,
                        outline: palette.outline,
                      ),
                    )
                  // Before a place is chosen the box would otherwise be a
                  // blank void, which is most of why step 1 read as plain.
                  : CustomPaint(painter: _EmptyBackdropPainter(palette)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                // The artwork puts the feet flush with the bottom of its own
                // frame, so this inset is what stands the hero on the scene's
                // ground band rather than on the very edge of the box.
                padding: EdgeInsets.only(bottom: height * 0.05),
                child: Image.asset(
                  hero.assetPath,
                  height: height * 0.86,
                  fit: BoxFit.contain,
                  // Drawn at 256px and shown larger on a tall window; without
                  // this the upscale is visibly blocky.
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            if (pet != null)
              Positioned(
                right: height * 0.06,
                // The same ground line as the hero, so the two stand together
                // rather than the companion floating in a corner.
                bottom: height * 0.05,
                child: Image.asset(
                  pet,
                  height: height * 0.40,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The backdrop before a place has been chosen.
///
/// Reads as the blank page of the sticker book: paper, a few inked bubbles,
/// and nothing that competes with the hero. The SRS rules out visual
/// distraction, so this is texture rather than decoration.
class _EmptyBackdropPainter extends CustomPainter {
  final StoryPalette palette;

  const _EmptyBackdropPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.surface, palette.ground],
        ).createShader(rect),
    );

    final ink = Paint()
      ..color = palette.outline.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void bubble(double fx, double fy, double fr, Color fill) {
      final center = Offset(size.width * fx, size.height * fy);
      final radius = size.shortestSide * fr;
      canvas.drawCircle(center, radius, Paint()..color = fill);
      canvas.drawCircle(center, radius, ink);
    }

    bubble(0.16, 0.26, 0.13, palette.tintYellow.withValues(alpha: 0.5));
    bubble(0.88, 0.20, 0.09, palette.tintBlue.withValues(alpha: 0.45));
    bubble(0.80, 0.74, 0.16, palette.tintMagenta.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(_EmptyBackdropPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
