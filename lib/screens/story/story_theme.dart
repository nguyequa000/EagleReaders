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

  /// The top bar on child-facing screens: yellow, the child dashboard's
  /// identity.
  final Color header;

  final Color headerInk;

  /// The top bar on grown-up screens — sign-in, the who's-reading picker, the
  /// parent PIN. Pink, so a parent can tell at a glance which side they are on.
  final Color headerParent;

  final Color headerParentInk;

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
  /// 6.5:1 or better and suits the drawn style besides.
  final Color onAction;

  final Color disabled;

  /// The unfilled part of the progress bar.
  final Color track;

  /// Sticker fills. Pastel, after the app's colour scheme, but a step deeper
  /// than the mock-ups' card tints so the coral and magenta tiles stay apart
  /// on the mood grid. All of them clear 10:1 against [ink].
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
    required this.headerParent,
    required this.headerParentInk,
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

  /// Warm white paper, plum ink, pastel stickers.
  static const StoryPalette light = StoryPalette(
    brightness: Brightness.light,
    ground: Color(0xFFFFFDF6),
    surface: Color(0xFFFFFFFF),
    header: Color(0xFFFEEDB7),
    headerInk: Color(0xFF382732),
    headerParent: Color(0xFFFEDCED),
    headerParentInk: Color(0xFF382732),
    ink: Color(0xFF382732),
    inkMuted: Color(0xFF756871),
    outline: Color(0xFF382732),
    shadowInk: Color(0xFF382732),
    paperFleck: Color(0xFFF6DCE9),
    line: Color(0xFFFFBFE2),
    action: Color(0xFF0CC1E0),
    onAction: Color(0xFF382732),
    disabled: Color(0xFFD8CCD3),
    track: Color(0xFFFFFFFF),
    tintBlue: Color(0xFFCDF2FB),
    tintCoral: Color(0xFFFFDCD3),
    tintMagenta: Color(0xFFFFD3EA),
    tintYellow: Color(0xFFFFEDB0),
    tintGreen: Color(0xFFD9F2CD),
  );

  /// A plum night, pale-pink ink. The headers go dark and keep their identity
  /// in the title instead — yellow for the child, pink for the parent — and
  /// the stickers keep their hues at low lightness, so the page reads as the
  /// same book under a lamp.
  static const StoryPalette dark = StoryPalette(
    brightness: Brightness.dark,
    ground: Color(0xFF1B1523),
    surface: Color(0xFF271E2F),
    header: Color(0xFF271E2F),
    headerInk: Color(0xFFFBD65F),
    headerParent: Color(0xFF271E2F),
    headerParentInk: Color(0xFFFF6EBE),
    ink: Color(0xFFFDF4F8),
    inkMuted: Color(0xFFBBADBE),
    outline: Color(0xFFF1E4EC),
    shadowInk: Color(0xFF0E0A14),
    paperFleck: Color(0xFF2A2134),
    line: Color(0xFF392D43),
    action: Color(0xFF0CC1E0),
    onAction: Color(0xFF13202A),
    disabled: Color(0xFF4A3F55),
    track: Color(0xFF271E2F),
    tintBlue: Color(0xFF17333F),
    tintCoral: Color(0xFF46261F),
    tintMagenta: Color(0xFF45203D),
    tintYellow: Color(0xFF393220),
    tintGreen: Color(0xFF1E3524),
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
  ///
  /// It also dresses the stock Material pieces the screens still use —
  /// dialogs, buttons, cards, chips, tabs, sliders, switches, checkboxes,
  /// spinners, snack bars, app bars — in the palette, so a plain
  /// [AlertDialog] or [FilledButton] anywhere in the app already belongs.
  ///
  /// Text fields are the exception: see [formsFor].
  static ThemeData themeFor(StoryPalette palette) {
    final edge = BorderSide(color: palette.outline, width: outlineWidth);
    final cutOut = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusTile),
      side: edge,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
      side: edge,
    );
    final label = display(size: 16, color: palette.ink, weight: 700);
    WidgetStateProperty<Color?> whenOn(Color on, Color? off) =>
        WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? on : off,
        );
    return ThemeData(
      brightness: palette.brightness,
      scaffoldBackgroundColor: palette.ground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.action,
        brightness: palette.brightness,
        surface: palette.surface,
        primary: palette.action,
        onPrimary: palette.onAction,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.ground,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: display(size: 18, color: palette.ink, weight: 700),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.action,
        linearTrackColor: palette.track,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.action,
        inactiveTrackColor: palette.line,
        thumbColor: palette.action,
        valueIndicatorColor: palette.ink,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: cutOut,
        titleTextStyle: display(size: 20, color: palette.ink, weight: 700),
        contentTextStyle: body(color: palette.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(radiusTile),
          ),
          side: edge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.ink,
          textStyle: label,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.action,
          foregroundColor: palette.onAction,
          disabledBackgroundColor: palette.disabled,
          shape: buttonShape,
          textStyle: label,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          backgroundColor: palette.surface,
          side: edge,
          shape: buttonShape,
          textStyle: label,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cutOut,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.action,
        checkmarkColor: palette.onAction,
        labelStyle: body(color: palette.ink, weight: 700),
        side: BorderSide(color: palette.outline, width: outlineWidthThin),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.ink,
        unselectedLabelColor: palette.inkMuted,
        labelStyle: label,
        unselectedLabelStyle: label,
        indicatorColor: palette.action,
        dividerColor: palette.outline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: whenOn(palette.surface, palette.inkMuted),
        trackColor: whenOn(palette.action, palette.track),
        trackOutlineColor: WidgetStatePropertyAll(palette.outline),
        trackOutlineWidth: const WidgetStatePropertyAll(outlineWidthThin),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: whenOn(palette.action, Colors.transparent),
        checkColor: WidgetStatePropertyAll(palette.onAction),
        side: BorderSide(color: palette.outline, width: outlineWidthThin),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: body(color: palette.ground, weight: 600),
        actionTextColor: palette.action,
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1.5),
    );
  }

  /// [base] with text fields cut out like stickers: paper fill, ink edge,
  /// action-coloured when focused.
  ///
  /// Not part of [themeFor], because the story writer and summary draw their
  /// fields without a border on purpose and a global default would box them
  /// in. Applied with a [Theme] around screens built from plain
  /// [TextFormField]s (Manage Shelf); elsewhere fields use
  /// `stickerInputDecoration`.
  static ThemeData formsFor(ThemeData base, StoryPalette palette) {
    OutlineInputBorder field(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusButton),
      borderSide: BorderSide(color: color, width: outlineWidth),
    );
    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: body(color: palette.inkMuted),
        border: field(palette.outline),
        enabledBorder: field(palette.outline),
        focusedBorder: field(palette.action),
        errorBorder: field(palette.tintCoral),
        focusedErrorBorder: field(palette.tintCoral),
      ),
    );
  }
}
