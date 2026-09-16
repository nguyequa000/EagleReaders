import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'hero_config.dart';
import 'story_theme.dart';

/// The big preview box that sits across the top half of every step.
///
/// The hero is regenerated from [hero] on each build rather than cached. An
/// Avataaars render is a few hundred microseconds of string assembly, and
/// caching it would mean holding a copy that can silently disagree with the
/// options the rows are showing.
class HeroPreview extends StatelessWidget {
  final HeroConfig hero;

  /// Height of the box. The builder gives it less room than the later steps,
  /// because it has three rows of controls to fit underneath.
  final double height;

  /// Drawn behind the hero — the chosen place, once screen 3 exists.
  final Widget? backdrop;

  /// The story's mood, which decides the hero's expression.
  ///
  /// Null while no mood has been chosen, which renders the default happy face
  /// rather than an expressionless one.
  final String? mood;

  const HeroPreview({
    super.key,
    required this.hero,
    this.height = 260,
    this.backdrop,
    this.mood,
  });

  @override
  Widget build(BuildContext context) {
    final pet = hero.petAsset;

    return Semantics(
      excludeSemantics: true,
      label: hero.name == null
          ? 'Your hero'
          : 'Your hero, ${hero.name}',
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: StoryTheme.card,
          borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
          border: Border.all(color: StoryTheme.shadow),
          boxShadow: StoryTheme.hardShadow(),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (backdrop != null) Positioned.fill(child: backdrop!),
            Align(
              alignment: const Alignment(0, 0.18),
              child: SvgPicture.string(
                hero.toSvgForMood(mood, size: 420),
                height: height * 0.92,
                // The hero is the subject of this box; letting it overflow the
                // sides is better than letterboxing it into a stamp.
                fit: BoxFit.contain,
              ),
            ),
            if (pet != null)
              Positioned(
                right: 14,
                bottom: 12,
                child: Image.asset(pet, width: 64, height: 64),
              ),
          ],
        ),
      ),
    );
  }
}
