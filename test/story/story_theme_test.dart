import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  group('palettes', () {
    test('both modes define every role', () {
      // A role missing from one mode is the classic half-themed bug: the
      // screen renders one mode's text on the other mode's ground.
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        for (final color in <Color>[
          palette.ground,
          palette.surface,
          palette.header,
          palette.headerInk,
          palette.ink,
          palette.inkMuted,
          palette.line,
          palette.action,
          palette.onAction,
          palette.disabled,
          palette.track,
        ]) {
          expect(color.a, 1.0, reason: 'roles are opaque');
        }
        expect(palette.tints, hasLength(5));
      }
    });

    test('the action colour is the same in both modes', () {
      // Deliberate: it is the one thing that does not move, so "this is what
      // you press" survives the theme switch.
      expect(StoryPalette.light.action, StoryPalette.dark.action);
    });

    test('the two modes are actually different', () {
      expect(StoryPalette.light.ground, isNot(StoryPalette.dark.ground));
      expect(StoryPalette.light.ink, isNot(StoryPalette.dark.ink));
      expect(StoryPalette.light.isDark, isFalse);
      expect(StoryPalette.dark.isDark, isTrue);
    });

    test('each mode has enough contrast between ink and ground', () {
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        final inkL = palette.ink.computeLuminance();
        final groundL = palette.ground.computeLuminance();
        final ratio = (max(inkL, groundL) + 0.05) / (min(inkL, groundL) + 0.05);
        expect(
          ratio,
          greaterThan(7.0),
          reason: 'body text on the ground must clear AA comfortably',
        );
      }
    });

    test('surface is distinguishable from ground in both modes', () {
      // Dark mode draws no shadow, so a card is told apart from the ground by
      // this difference alone.
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        expect(
          palette.surface,
          isNot(palette.ground),
          reason: 'a card must read as lifted',
        );
      }
    });

    test('the tints are distinct within a mode', () {
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        // The tints replaced the per-step accents as the way four options stay
        // apart, so they cannot collide.
        expect(palette.tints.toSet(), hasLength(palette.tints.length));
      }
    });

    test('tintForIndex wraps instead of throwing', () {
      const palette = StoryPalette.light;
      expect(palette.tintForIndex(0), palette.tints.first);
      expect(palette.tintForIndex(5), palette.tints.first);
      expect(palette.tintForIndex(7), palette.tints[2]);
    });

    test('the sticker lift is hard, in both modes, and collapses on press', () {
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        final lift = palette.cardShadow();
        expect(lift, hasLength(1));
        // No blur at all. A blurred shadow is the soft material look this
        // style is deliberately not, and it is what made the old screens read
        // as a generic app rather than a drawn page.
        expect(lift.first.blurRadius, 0);
        expect(
          lift.first.offset,
          const Offset(StoryTheme.depth, StoryTheme.depth),
        );
        expect(lift.first.color, palette.shadowInk);
        expect(palette.cardShadow(pressed: true), isEmpty);
      }
    });

    test('the ink line flips for dark mode but the shadow does not', () {
      // The outline goes cream so a sticker still reads as cut out on a dark
      // desk. The shadow has to stay dark in both modes, or it stops being a
      // gap under the sticker and becomes a glow around it.
      expect(StoryPalette.light.outline.computeLuminance(), lessThan(0.1));
      expect(StoryPalette.dark.outline.computeLuminance(), greaterThan(0.5));
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        expect(palette.shadowInk.computeLuminance(), lessThan(0.05));
      }
    });

    test('every sticker tint can carry its label', () {
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        for (final tint in palette.tints) {
          expect(
            contrast(palette.ink, tint),
            greaterThanOrEqualTo(4.5),
            reason: 'an option label on $tint is unreadable',
          );
        }
      }
    });

    test('the action colour can carry its own label', () {
      // Regression cover. This was white on cyan at about 2.1:1 — on the
      // primary control of the flow, for the youngest users in the app.
      for (final palette in <StoryPalette>[
        StoryPalette.light,
        StoryPalette.dark,
      ]) {
        expect(
          contrast(palette.onAction, palette.action),
          greaterThanOrEqualTo(4.5),
          reason: 'the Next button label is unreadable',
        );
      }
    });
  });

  group('resolution', () {
    testWidgets('of() follows the ambient theme mode', (tester) async {
      late StoryPalette seen;
      // Configured exactly as main.dart configures the app, so this asserts
      // the real path rather than a contrived one.
      Future<void> pumpIn(ThemeMode mode) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: StoryTheme.themeFor(StoryPalette.light),
            darkTheme: StoryTheme.themeFor(StoryPalette.dark),
            themeMode: mode,
            home: Builder(
              builder: (context) {
                seen = StoryTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        // pumpAndSettle, not pump: MaterialApp crossfades between themes, so a
        // single frame after the switch still reports the old brightness.
        await tester.pumpAndSettle();
      }

      await pumpIn(ThemeMode.light);
      expect(seen.isDark, isFalse);
      expect(seen.ground, StoryPalette.light.ground);

      await pumpIn(ThemeMode.dark);
      expect(seen.isDark, isTrue);
      expect(seen.ground, StoryPalette.dark.ground);
    });

    test('themeFor carries the palette into ThemeData', () {
      final dark = StoryTheme.themeFor(StoryPalette.dark);
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, StoryPalette.dark.ground);
    });
  });

  group('typography', () {
    test('display uses Fredoka and body uses Nunito', () {
      const ink = Color(0xFF000000);
      expect(StoryTheme.display(color: ink).fontFamily, 'Fredoka');
      expect(StoryTheme.body(color: ink).fontFamily, 'Nunito');
    });

    test('text styles carry an explicit weight axis', () {
      final style = StoryTheme.display(
        color: const Color(0xFF000000),
        weight: 600,
      );
      expect(style.fontVariations!.single.axis, 'wght');
      expect(style.fontVariations!.single.value, 600);
    });
  });
}
