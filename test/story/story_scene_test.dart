import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_option.dart';
import 'package:storysprout/screens/story/story_theme.dart';
import 'package:storysprout/screens/story/story_scene.dart';

/// Stands in for the palette's outline colour.
const Color ink = Color(0xFF2B2235);

void main() {
  test('every place a child can choose has a scene to draw', () {
    // The setting grid and the scene catalogue have to agree, or picking a
    // place leaves the preview blank — which is the bug this replaced.
    for (final option in StoryOptions.settings) {
      expect(
        StoryScene.forLabel(option.label),
        isNotNull,
        reason: '${option.label} has no scene',
      );
    }
    expect(StoryScene.all, hasLength(StoryOptions.settings.length));
  });

  test('an unchosen place has no scene', () {
    expect(StoryScene.forLabel(null), isNull);
    expect(StoryScene.forLabel('Atlantis'), isNull);
  });

  test('scenes describe themselves proportionally', () {
    // Fractions of the box, so the same scene survives a 180px preview and a
    // full-width banner.
    for (final scene in StoryScene.all) {
      expect(scene.elements, isNotEmpty, reason: scene.label);
      for (final e in scene.elements) {
        expect(e.x, inInclusiveRange(0.0, 1.0), reason: scene.label);
        expect(e.y, inInclusiveRange(0.0, 1.0), reason: scene.label);
        expect(e.scale, greaterThan(0));
      }
    }
  });

  test('the dark variant dims without losing anything', () {
    const ground = Color(0xFF1B1523);
    for (final scene in StoryScene.all) {
      final night = scene.forDark(ground);
      expect(night.label, scene.label);
      expect(
        night.elements,
        hasLength(scene.elements.length),
        reason: 'dimming must not drop elements',
      );
      expect(
        night.skyTop.computeLuminance(),
        lessThan(scene.skyTop.computeLuminance()),
        reason: '${scene.label} sky should darken',
      );
    }
  });

  testWidgets('every scene paints at any size without throwing', (
    tester,
  ) async {
    for (final scene in StoryScene.all) {
      for (final size in const <Size>[Size(180, 120), Size(400, 300)]) {
        await tester.pumpWidget(
          Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: StoryScenePainter(scene, outline: ink),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${scene.label} at $size',
        );
      }
    }
  });

  testWidgets('a scene repaints only when the scene changes', (tester) async {
    const a = StoryScenePainter(StoryScene.forest, outline: ink);
    const b = StoryScenePainter(StoryScene.ocean, outline: ink);
    expect(a.shouldRepaint(b), isTrue);
    expect(
      a.shouldRepaint(const StoryScenePainter(StoryScene.forest, outline: ink)),
      isFalse,
    );

    // The ink flips to cream in dark mode, so a scene that is otherwise
    // identical still has to redraw.
    expect(
      a.shouldRepaint(
        const StoryScenePainter(StoryScene.forest, outline: Color(0xFFF3E7CE)),
      ),
      isTrue,
    );
  });

  test('the palette exposes what the scenes need for night', () {
    // forDark blends toward the ground, so the ground has to be a real colour
    // in both modes or night scenes would wash out.
    expect(StoryPalette.dark.ground.a, 1.0);
    expect(StoryPalette.light.ground.a, 1.0);
  });

  test('a mood changes the light without changing the place', () {
    // Step 3 has to show its own consequence. The hero's pose is the child's
    // choice from step 1, so what the feeling moves is the weather.
    for (final scene in StoryScene.all) {
      final spooky = scene.forMood('Spooky');
      final funny = scene.forMood('Funny');

      expect(spooky.label, scene.label, reason: 'the place does not change');
      expect(spooky.elements, hasLength(scene.elements.length));
      expect(spooky.skyTop, isNot(scene.skyTop), reason: scene.label);
      expect(
        spooky.skyTop,
        isNot(funny.skyTop),
        reason: 'two feelings that look alike make the choice feel inert',
      );
      expect(
        spooky.skyTop.computeLuminance(),
        lessThan(funny.skyTop.computeLuminance()),
        reason: 'spooky should read darker than funny',
      );
    }
  });

  test('an unchosen or unknown mood leaves the scene alone', () {
    // Guessing here would quietly repaint the place a child deliberately
    // picked, so an unrecognised mood is a no-op rather than a default.
    for (final scene in StoryScene.all) {
      expect(scene.forMood(null).skyTop, scene.skyTop);
      expect(scene.forMood('nonsense').skyTop, scene.skyTop);
    }
  });

  test('mood matching is case-insensitive', () {
    expect(
      StoryScene.forest.forMood('spooky').skyTop,
      StoryScene.forest.forMood('Spooky').skyTop,
    );
  });

  test('a mood and dark mode compose without losing elements', () {
    const ground = Color(0xFF1B1523);
    for (final scene in StoryScene.all) {
      final night = scene.forMood('Calm').forDark(ground);
      expect(
        night.elements,
        hasLength(scene.elements.length),
        reason: scene.label,
      );
      expect(night.label, scene.label);
    }
  });
}
