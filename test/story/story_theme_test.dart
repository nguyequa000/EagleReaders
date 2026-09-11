import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  test('accentForStep maps each step to its own colour', () {
    expect(StoryTheme.accentForStep(1), StoryTheme.accentCharacter);
    expect(StoryTheme.accentForStep(2), StoryTheme.accentMood);
    expect(StoryTheme.accentForStep(3), StoryTheme.accentSetting);
    expect(StoryTheme.accentForStep(4), StoryTheme.accentComplete);
  });

  test('the four step accents are all distinct', () {
    final accents = {
      StoryTheme.accentForStep(1),
      StoryTheme.accentForStep(2),
      StoryTheme.accentForStep(3),
      StoryTheme.accentForStep(4),
    };
    expect(accents.length, 4);
  });

  test('hardShadow has zero blur when resting and vanishes when pressed', () {
    final resting = StoryTheme.hardShadow();
    expect(resting, hasLength(1));
    expect(resting.first.blurRadius, 0);
    expect(resting.first.offset, const Offset(0, StoryTheme.depth));

    expect(StoryTheme.hardShadow(pressed: true), isEmpty);
  });

  test('display uses Fredoka and body uses Nunito', () {
    expect(StoryTheme.display().fontFamily, 'Fredoka');
    expect(StoryTheme.body().fontFamily, 'Nunito');
  });

  test('text styles carry an explicit weight axis', () {
    final style = StoryTheme.display(weight: 600);
    expect(style.fontVariations!.single.axis, 'wght');
    expect(style.fontVariations!.single.value, 600);
  });
}
