import 'package:flutter/material.dart';

import 'screens/story/story_theme.dart';

/// The reader's "Paper" page: the scheme's yellow, softened to something a
/// child can read on for a whole chapter. Warmer than "White" (the palette's
/// card white), so the two choices look different.
const readingPaper = Color(0xFFFFF4DA);

/// The palette for a reader page: the dark one for the "Dark" page, the light
/// one for "Paper" and "White", whatever mode the rest of the app is in, so
/// the toolbar and controls always agree with the page under them.
StoryPalette readingPalette({bool dark = false}) =>
    dark ? StoryPalette.dark : StoryPalette.light;

/// The page colour for each of the reader's page choices.
Color readingBackground(String readerTheme) => switch (readerTheme) {
  'dark' => StoryPalette.dark.ground,
  'white' => StoryPalette.light.surface,
  _ => readingPaper,
};

ThemeData readingTheme(BuildContext context, {bool dark = false}) =>
    StoryTheme.themeFor(readingPalette(dark: dark));
