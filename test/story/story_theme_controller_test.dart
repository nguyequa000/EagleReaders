import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/story/story_theme.dart';
import 'package:storysprout/screens/story/story_theme_controller.dart';
import 'package:storysprout/screens/story_flow_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storyThemeController.value = ThemeMode.system;
  });

  group('controller', () {
    test('starts out following the device', () {
      // A device already in dark mode at bedtime should not be handed a white
      // screen, and bedtime is when this app is most likely to be open.
      expect(StoryThemeController().value, ThemeMode.system);
    });

    test('cycles through all three modes and back', () async {
      final controller = StoryThemeController();
      final seen = <ThemeMode>[controller.value];
      for (var i = 0; i < 3; i++) {
        await controller.next();
        seen.add(controller.value);
      }
      expect(
        seen.take(3).toSet(),
        ThemeMode.values.toSet(),
        reason: 'every mode has to be reachable',
      );
      expect(seen.last, seen.first, reason: 'and the cycle has to come back');
    });

    test('remembers the choice across a restart', () async {
      final first = StoryThemeController();
      await first.next();
      await first.next();
      final chosen = first.value;

      final second = StoryThemeController();
      await second.load();
      expect(second.value, chosen);
    });

    test('an empty store leaves it following the device', () async {
      final controller = StoryThemeController(ThemeMode.dark);
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('the label and icon name the mode in force', () async {
      final controller = StoryThemeController();
      final labels = <String>{};
      final icons = <IconData>{};
      for (var i = 0; i < ThemeMode.values.length; i++) {
        labels.add(controller.label);
        icons.add(controller.icon);
        await controller.next();
      }
      expect(labels, hasLength(ThemeMode.values.length));
      expect(icons, hasLength(ThemeMode.values.length));
    });
  });

  group('in the flow', () {
    Future<void> pumpFlow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: storyThemeController,
          builder: (context, mode, _) => MaterialApp(
            theme: StoryTheme.themeFor(StoryPalette.light),
            darkTheme: StoryTheme.themeFor(StoryPalette.dark),
            themeMode: mode,
            home: const StoryFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color groundOf(WidgetTester tester) {
      return tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .backgroundColor!;
    }

    testWidgets('the header switch repaints the whole screen', (tester) async {
      await pumpFlow(tester);
      expect(groundOf(tester), StoryPalette.light.ground);

      // system -> light -> dark
      await tester.tap(find.byIcon(Icons.brightness_auto));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.light_mode));
      await tester.pumpAndSettle();

      expect(storyThemeController.value, ThemeMode.dark);
      expect(groundOf(tester), StoryPalette.dark.ground);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('every step draws in the dark without throwing', (
      tester,
    ) async {
      storyThemeController.value = ThemeMode.dark;
      await pumpFlow(tester);

      Future<void> choose(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pump();
      }

      Future<void> next() async {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(groundOf(tester), StoryPalette.dark.ground);
      expect(tester.takeException(), isNull, reason: 'step 1');
      await next();

      await choose('Ocean');
      expect(tester.takeException(), isNull, reason: 'step 2, scene painted');
      await next();

      await choose('Spooky');
      expect(tester.takeException(), isNull, reason: 'step 3, mood over scene');
      await next();

      expect(tester.takeException(), isNull, reason: 'step 4');
      expect(groundOf(tester), StoryPalette.dark.ground);
    });

    testWidgets('the switch survives moving between steps', (tester) async {
      storyThemeController.value = ThemeMode.dark;
      await pumpFlow(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(
        groundOf(tester),
        StoryPalette.dark.ground,
        reason: 'the choice belongs to the app, not to one screen',
      );
    });
  });
}
