import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which theme the app draws in, and the one place that decides it.
///
/// Dark mode existed before this but could only be reached by changing the
/// device's own setting, which meant nobody could see it from inside the app.
/// This makes it a choice.
///
/// The default stays [ThemeMode.system] rather than light: a device already in
/// dark mode at bedtime should not be handed a white screen, and bedtime is
/// when this app is most likely to be open.
class StoryThemeController extends ValueNotifier<ThemeMode> {
  StoryThemeController([super.initial = ThemeMode.system]);

  static const String _key = 'story.themeMode';

  /// The order the toggle walks through.
  ///
  /// System sits between the two so a child who taps past the mode they wanted
  /// reaches it again in three taps rather than being stuck flipping between
  /// two.
  static const List<ThemeMode> _cycle = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  /// Reads the saved choice. Falls back to following the device.
  ///
  /// A failure here is not worth blocking startup for — the app simply opens
  /// in the device's own mode, which is what it did before this existed.
  Future<void> load() async {
    try {
      final stored = (await SharedPreferences.getInstance()).getString(_key);
      value = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  /// Moves to the next mode and remembers it.
  Future<void> next() async {
    value = _cycle[(_cycle.indexOf(value) + 1) % _cycle.length];
    try {
      await (await SharedPreferences.getInstance()).setString(_key, value.name);
    } catch (_) {
      // An unwritable store costs the child nothing this session; the choice
      // simply does not survive a restart.
    }
  }

  /// What the control should say it does, for a screen reader and a tooltip.
  String get label {
    switch (value) {
      case ThemeMode.system:
        return 'Theme: follows your device';
      case ThemeMode.light:
        return 'Theme: day';
      case ThemeMode.dark:
        return 'Theme: night';
    }
  }

  /// The icon for the mode currently in force.
  IconData get icon {
    switch (value) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}

/// The app's single controller.
///
/// A plain global rather than an inherited widget: one app-wide switch, read
/// by `main()` and written by one button, and threading a provider through
/// four screens to carry it would be the more complicated thing.
final StoryThemeController storyThemeController = StoryThemeController();
