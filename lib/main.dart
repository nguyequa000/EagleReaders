import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/story/story_theme.dart';
import 'screens/story/story_theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Restores the saved theme before the first frame, so the app never opens in
  // one mode and flips to the other a moment later.
  await storyThemeController.load();
  runApp(const StorySproutApp());
}

class StorySproutApp extends StatelessWidget {
  const StorySproutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: storyThemeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Story Sprout',
          // Both modes are always built. Without a darkTheme the app is always
          // light regardless of the setting, so the dark half of the design
          // would be unreachable.
          theme: StoryTheme.themeFor(StoryPalette.light),
          darkTheme: StoryTheme.themeFor(StoryPalette.dark),
          themeMode: mode,
          // Skips the login screen when this device is still signed in.
          home: const AuthGate(),
        );
      },
    );
  }
}
