import 'package:flutter/material.dart';

/// The colours of one theme mode.
///
/// The story flow is drawn as a sticker book: saturated shapes cut out with a
/// heavy ink line and pressed onto a sheet of paper. That is a deliberate
/// departure from the quiet, pale-tinted cards the parent screens use. The two
/// registers belong to two different readers — a parent scanning reading stats
/// wants calm, and a five-year-old inventing a story wants the crayon box.
///
/// The two modes are a matched pair: every role exists in both, and a tile
/// stays recognisably "the blue one" after the switch. What changes between
/// them is which way the ink runs — dark ink on cream paper in light mode,
/// cream ink on a dark desk in dark mode.
@immutable
class StoryPalette {
  final Brightness brightness;

  /// The paper itself, behind everything.
  final Color ground;

  /// Cards and panels that are paper rather than sticker — the preview box,
  /// the name field.
  final Color surface;

  /// The top bar. Child-facing, so it carries the yellow identity the child
  /// dashboard uses; the parent screens are the pink ones.
  final Color header;

  final Color headerInk;

  final Color ink;
  final Color inkMuted;

  /// The heavy line every sticker is cut out with.
  ///
  /// Dark in light mode, cream in dark mode, so a sticker always reads as a
  /// shape lifted off the sheet rather than a hole punched in it.
  final Color outline;

  /// The hard drop shadow under a sticker.
  ///
  /// Always dark, in both modes — it stands for the gap between the sticker
  /// and the page, and a light shadow would read as a glow instead. This is
  /// why it is its own token rather than reusing [outline].
  final Color shadowInk;

  /// The speckle in the paper. Barely visible by design.
  final Color paperFleck;

  /// Hairline rules, for the few places that want a divider rather than a
  /// cut-out edge.
  final Color line;

  /// The one action colour — buttons, selected rings, the progress fill.
  final Color action;

  /// Text and icons drawn on [action].
  ///
  /// Dark ink, not white. White on this cyan measures about 2.1:1, well under
  /// the 4.5:1 minimum, and it was sitting on the most important control in
  /// the flow for the youngest users in the app. Dark ink on the same cyan is
  /// about 7.6:1 and suits the drawn style besides.
  final Color onAction;

  final Color disabled;

  /// The unfilled part of the progress bar.
  final Color track;

  /// Sticker fills. Saturated enough to carry the ink line, and all of them
  /// clear 6.5:1 against [ink] so the labels stay legible.
  final Color tintBlue;
  final Color tintCoral;
  final Color tintMagenta;
  final Color tintYellow;
  final Color tintGreen;

  const StoryPalette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.header,
    required this.headerInk,
    required this.ink,
    required this.inkMuted,
    required this.outline,
    required this.shadowInk,
    required this.paperFleck,
    required this.line,
    required this.action,
    required this.onAction,
    required this.disabled,
    required this.track,
    required this.tintBlue,
    required this.tintCoral,
    required this.tintMagenta,
    required this.tintYellow,
    required this.tintGreen,
  });

  /// Cream paper, dark ink.
  static const StoryPalette light = StoryPalette(
    brightness: Brightness.light,
    ground: Color(0xFFFFF8E7),
    surface: Color(0xFFFFFCF2),
    header: Color(0xFFFFD23F),
    headerInk: Color(0xFF2B2235),
    ink: Color(0xFF2B2235),
    inkMuted: Color(0xFF6B5F52),
    outline: Color(0xFF2B2235),
    shadowInk: Color(0xFF2B2235),
    paperFleck: Color(0xFFE8D9B5),
    line: Color(0xFFE4D6B8),
    action: Color(0xFF0CC1E0),
    onAction: Color(0xFF2B2235),
    disabled: Color(0xFFC9BDA6),
    track: Color(0xFFFFFCF2),
    tintBlue: Color(0xFF5BC8E8),
    tintCoral: Color(0xFFFFA552),
    tintMagenta: Color(0xFFFF8FA3),
    tintYellow: Color(0xFFFFD23F),
    tintGreen: Color(0xFF8ED081),
  );

  /// A dark desk, cream ink. The stickers keep their hues and lose their
  /// lightness, so the page reads as the same book under a lamp.
  static const StoryPalette dark = StoryPalette(
    brightness: Brightness.dark,
    ground: Color(0xFF221C2E),
    surface: Color(0xFF2C2439),
    header: Color(0xFF3B3119),
    headerInk: Color(0xFFFFD23F),
    ink: Color(0xFFF6EEDC),
    inkMuted: Color(0xFFB3A48C),
    outline: Color(0xFFF3E7CE),
    shadowInk: Color(0xFF100B18),
    paperFleck: Color(0xFF2F2740),
    line: Color(0xFF3A3047),
    action: Color(0xFF0CC1E0),
    onAction: Color(0xFF13202A),
    disabled: Color(0xFF5A4F66),
    track: Color(0xFF2C2439),
    tintBlue: Color(0xFF15455A),
    tintCoral: Color(0xFF5C3317),
    tintMagenta: Color(0xFF5A2434),
    tintYellow: Color(0xFF5A4412),
    tintGreen: Color(0xFF234A2A),
  );

  bool get isDark => brightness == Brightness.dark;

  /// The five tints in a fixed order, so a caller can index into them.
  List<Color> get tints => <Color>[
    tintYellow,
    tintBlue,
    tintMagenta,
    tintCoral,
    tintGreen,
  ];

  /// Tint for a 0-based option index, wrapping.
  ///
  /// This is how the flow keeps four distinguishable categories now that every
  /// action is one colour: the difference moved from the buttons to the tiles.
  Color tintForIndex(int index) => tints[index % tints.length];

  /// The hard offset shadow that lifts a sticker off the page.
  ///
  /// No blur at all — a blurred shadow is the soft material look this style is
  /// deliberately not. Collapses on press so the sticker presses flat, which
  /// pairs with the caller translating it down by [StoryTheme.depth].
  List<BoxShadow> cardShadow({
    bool pressed = false,
    double depth = StoryTheme.depth,
  }) {
    if (pressed) return const <BoxShadow>[];
    return <BoxShadow>[
      BoxShadow(color: shadowInk, offset: Offset(depth, depth), blurRadius: 0),
    ];
  }
}

/// Design tokens for the story creation flow.
///
/// Colours come from [StoryPalette] and depend on the ambient theme, so they
/// are reached through [of]. Shape and typography do not change between modes
/// and stay static.
class StoryTheme {
  const StoryTheme._();

  /// The palette for the current theme mode.
  static StoryPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? StoryPalette.dark
      : StoryPalette.light;

  // Shape
  static const double radiusTile = 20;
  static const double radiusButton = 16;

  /// How far a sticker sits off the page, and so how far it travels on press.
  static const double depth = 4;

  /// The cut-out line around a sticker.
  static const double outlineWidth = 3;

  /// A lighter cut, for small elements where the full weight would close up
  /// the shape.
  static const double outlineWidthThin = 2.5;

  static const double ringWidth = 3;

  /// Display face. Headers, option labels, button labels, progress text.
  ///
  /// Heavier by default than the parent screens use: a drawn style wants the
  /// weight, and these labels are read by children still learning to.
  static TextStyle display({
    double size = 20,
    required Color color,
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
    required Color color,
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

  /// The app-wide themes, so the story screens sit on a ground that agrees
  /// with them and [of] can tell which mode is active.
  static ThemeData themeFor(StoryPalette palette) {
    return ThemeData(
      brightness: palette.brightness,
      scaffoldBackgroundColor: palette.ground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.action,
        brightness: palette.brightness,
        surface: palette.surface,
      ),
      useMaterial3: true,
    );
  }
}
