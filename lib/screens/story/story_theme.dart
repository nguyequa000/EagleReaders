import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Design tokens for the story creation flow.
///
/// Chrome is deliberately quiet so the colourful OpenMoji illustrations carry
/// the colour. Each step owns an accent, so the flow reads as a journey rather
/// than the same screen four times.
class StoryTheme {
  const StoryTheme._();

  // Structure
  static const Color brand = Color(0xFF3D6B1A);
  static const Color ground = Color(0xFFF5F0DC);
  static const Color card = Color(0xFFFFFDF7);
  static const Color ink = Color(0xFF2B2A26);
  static const Color inkMuted = Color(0xFF6B6558);
  static const Color shadow = Color(0xFFD8CFB4);
  static const Color disabled = Color(0xFFC9C2AE);

  // Per-step accents
  static const Color accentCharacter = Color(0xFF4C5BA8);
  static const Color accentMood = Color(0xFFD98324);
  static const Color accentSetting = Color(0xFF2A8C82);
  static const Color accentComplete = Color(0xFF4A7C20);

  // Shape
  static const double radiusTile = 20;
  static const double radiusButton = 14;
  static const double depth = 3;
  static const double ringWidth = 2.5;

  /// Accent for a 1-based step index. Steps beyond 4 reuse the completion green.
  static Color accentForStep(int step) {
    switch (step) {
      case 1:
        return accentCharacter;
      case 2:
        return accentMood;
      case 3:
        return accentSetting;
      default:
        return accentComplete;
    }
  }

  /// A hard offset shadow — zero blur, warm hue. Collapses to nothing while
  /// pressed so the element appears to physically depress.
  static List<BoxShadow> hardShadow({bool pressed = false}) {
    if (pressed) return const <BoxShadow>[];
    return const <BoxShadow>[
      BoxShadow(color: shadow, offset: Offset(0, depth), blurRadius: 0),
    ];
  }

  /// Display face. Headers, option labels, button labels, progress text.
  static TextStyle display({
    double size = 20,
    Color color = ink,
    double weight = 600,
    double tracking = 0,
  }) {
    return TextStyle(
      fontFamily: 'Fredoka',
      fontSize: size,
      color: color,
      letterSpacing: tracking,
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
    );
  }

  /// Body face. Sprout's dialogue and helper text.
  static TextStyle body({
    double size = 15,
    Color color = ink,
    double weight = 400,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      color: color,
      height: height,
      fontVariations: <FontVariation>[FontVariation('wght', weight)],
    );
  }
}
