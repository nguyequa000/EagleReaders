import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/screens/story_mode_screen.dart';
import 'package:storysprout/screens/story_mood_screen.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/screens/story_writer_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/reader_audience.dart';
import 'package:storysprout/services/story_generator.dart';

import 'test_helpers.dart';

/// Each Parent Settings switch where the child meets it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    FamilySettings.instance = FamilySettings();
    ReaderAudience.current = AgeBand.fallback;
  });

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('story reader', () {
    Future<void> readToTheEnd(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: StoryReaderScreen(
            config: const StoryConfig(hero: HeroConfig(name: 'Fox')),
            childId: '1',
            generate: (_, {soFar, choice}) async => Story.fromJson({
              'title': 'Fox and the Hat',
              'pages': [
                {'pageNumber': 1, 'text': 'Fox saw a hat.'},
              ],
              'questions': [
                {
                  'question': 'What did Fox find?',
                  'answers': ['A hat', 'A shoe', 'A cup'],
                  'correct': 0,
                },
              ],
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('AI quizzes off: the story just ends, no quiz', (tester) async {
      FamilySettings.instance.ai = const AiSettings(aiQuizzes: false);
      await readToTheEnd(tester);
      expect(find.text('Quiz time!'), findsNothing);
      await tapVisible(tester, 'The End');
      expect(find.byType(ComprehensionScreen), findsNothing);
    });

    testWidgets('AI quizzes on: the quiz follows the story', (tester) async {
      await readToTheEnd(tester);
      await tapVisible(tester, 'Quiz time!');
      expect(find.byType(ComprehensionScreen), findsOneWidget);
    });

    testWidgets('Read Aloud off hides the button', (tester) async {
      await readToTheEnd(tester);
      expect(find.byTooltip('Read aloud'), findsOneWidget);

      FamilySettings.instance.ai = const AiSettings(readAloud: false);
      await tester.pumpWidget(const SizedBox());
      await readToTheEnd(tester);
      expect(find.byTooltip('Read aloud'), findsNothing);
    });
  });

  group('story flow', () {
    Future<void> toSummary(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(const MaterialApp(home: StoryFlowScreen()));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Next');
      await tapVisible(tester, 'Forest');
      await tapVisible(tester, 'Next');
    }

    testWidgets('AI stories off: straight to writing, Back to the summary', (
      tester,
    ) async {
      FamilySettings.instance.ai = const AiSettings(aiStories: false);
      await toSummary(tester);
      await tapVisible(tester, 'Calm');
      await tapVisible(tester, 'Next');
      await tapVisible(tester, 'Start Reading!');

      expect(find.byType(StoryModeScreen), findsNothing);
      expect(find.byType(StoryWriterScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(StorySummaryScreen), findsOneWidget);
    });

    testWidgets("Sprout's ideas off: the writer has no idea buttons", (
      tester,
    ) async {
      FamilySettings.instance.ai = const AiSettings(sproutIdeas: false);
      await toSummary(tester);
      await tapVisible(tester, 'Calm');
      await tapVisible(tester, 'Next');
      await tapVisible(tester, 'Start Reading!');
      await tapVisible(tester, 'Advanced writer');

      expect(find.text('Need an idea?'), findsNothing);
      expect(find.text("I'm done!"), findsOneWidget);
      await tapVisible(tester, 'Beginning · Middle · End');
      expect(find.text('Ask Sprout'), findsNothing);
    });

    testWidgets('ages 3–5 get no Spooky feeling', (tester) async {
      ReaderAudience.current = AgeBand.ages3to5;
      await toSummary(tester);
      expect(find.byType(StoryMoodScreen), findsOneWidget);
      expect(find.text('Spooky'), findsNothing);
      expect(find.text('Calm'), findsOneWidget);
    });

    testWidgets('older children still get Spooky', (tester) async {
      await toSummary(tester);
      expect(find.text('Spooky'), findsOneWidget);
    });
  });

  group('child dashboard', () {
    late ActivityService activity;

    setUp(() {
      final fb = signedIn();
      activity = fb.activity;
      ActivityService.instance = fb.activity;
      CoinService.instance = fb.coins;
      FamilySettings.instance = FamilySettings(
        firestore: fb.firestore,
        auth: fb.auth,
      );
    });

    Future<void> pumpDashboard(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: ChildDashboardScreen(childId: '1', childName: 'Mika'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a used-up limit locks reading until a grown-up unlocks', (
      tester,
    ) async {
      await FamilySettings.instance.saveChild(
        '1',
        const ChildRules(dailyLimitMinutes: 15),
      );
      await activity.logEvent('1', 'reading_session', {
        'title': 'Alice',
        'minutes': 20,
      });
      await pumpDashboard(tester);

      expect(find.byKey(const Key('done-for-today')), findsOneWidget);

      // Create a Story waits until tomorrow.
      await tester.tap(find.text('Create a Story'));
      await tester.pumpAndSettle();
      expect(
        find.text("You've used today's reading time. Come back tomorrow!"),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('sheet-unlock')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('done-for-today')), findsNothing);
      final rules = await FamilySettings.instance.loadChild('1');
      expect(rules.limitUnlockedOn, dayKey(DateTime.now()));
    });

    testWidgets('under the limit, nothing is locked', (tester) async {
      await FamilySettings.instance.saveChild(
        '1',
        const ChildRules(dailyLimitMinutes: 30),
      );
      await activity.logEvent('1', 'reading_session', {
        'title': 'Alice',
        'minutes': 10,
      });
      await pumpDashboard(tester);
      expect(find.byKey(const Key('done-for-today')), findsNothing);
    });

    testWidgets('the reminder shows only when on and nothing read today', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(find.byKey(const Key('reading-reminder')), findsNothing);

      await FamilySettings.instance.save(
        const AiSettings(readingReminder: true),
      );
      await tester.pumpWidget(const SizedBox());
      await pumpDashboard(tester);
      expect(find.byKey(const Key('reading-reminder')), findsOneWidget);

      await activity.logEvent('1', 'book_opened', {'title': 'Alice'});
      await tester.pumpWidget(const SizedBox());
      await pumpDashboard(tester);
      expect(find.byKey(const Key('reading-reminder')), findsNothing);
    });

    testWidgets('AI stories off hides the AI-written story presets', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(find.text('Dragon Adventure'), findsOneWidget);

      await FamilySettings.instance.save(const AiSettings(aiStories: false));
      await tester.pumpWidget(const SizedBox());
      await pumpDashboard(tester);
      expect(find.text('Dragon Adventure'), findsNothing);
    });

    testWidgets("opening the dashboard sets the child's reading level", (
      tester,
    ) async {
      await FamilySettings.instance.saveChild(
        '1',
        const ChildRules(ageBand: AgeBand.ages9to10),
      );
      await pumpDashboard(tester);
      expect(ReaderAudience.current, AgeBand.ages9to10);
    });
  });
}
