import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/my_story_screen.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story_mode_screen.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/screens/story_writer_screen.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/story_store.dart';

import 'test_helpers.dart';

void main() {
  /// The title the flow builds for an unbuilt hero in the Forest.
  ///
  /// Read from the catalogue rather than written out, so renaming a character
  /// cannot quietly break this the way deleting one did.
  final expectedTitle = '${HeroCatalog.heroes.first.label} in Forest';

  /// The flow's height depends on its content, so pin a size rather than
  /// leaving the 800x600 default — otherwise a layout change moves what
  /// counts as visible and these tests flap.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> completeFlow(WidgetTester tester) async {
    // Step 1 needs no choice — an unbuilt hero already draws a whole
    // character — so this stays about the bookkeeping rather than about
    // picking one. The place comes before the feeling.
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Forest');
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Funny');
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Start Reading!');
    await tapVisible(tester, 'Beginning writer');
  }

  testWidgets('Finishing the story flow records story_created for the child', (
    tester,
  ) async {
    usePhone(tester);
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;

    await tester.pumpWidget(
      const MaterialApp(home: StoryFlowScreen(childId: '1')),
    );
    await tester.pumpAndSettle();
    await completeFlow(tester);

    final docs = await activityDocs(fb.firestore, '1');
    expect(docs, hasLength(1));
    expect(docs.single['type'], 'story_created');
    expect(docs.single['title'], expectedTitle);
    expect((await fb.activity.getStats('1')).storiesCreated, 1);

    // ...and earns the story coins.
    await tester.pumpAndSettle();
    final coins = await ledgerDocs(fb.firestore, '1');
    expect(coins.single['reason'], 'story');
    expect(coins.single['amount'], CoinService.coinsPerStory);
    expect(coins.single['title'], expectedTitle);
    expect(find.text('🪙 +5 coins!'), findsOneWidget);
  });

  testWidgets('Without a child id the flow still works and logs nothing', (
    tester,
  ) async {
    usePhone(tester);
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;

    await tester.pumpWidget(const MaterialApp(home: StoryFlowScreen()));
    await tester.pumpAndSettle();
    await completeFlow(tester);

    expect(find.text('Your Story'), findsOneWidget);
    final children = await fb.firestore
        .collection('parents')
        .doc('parent-1')
        .collection('children')
        .get();
    expect(children.docs, isEmpty);
  });

  testWidgets('A second story from "Create Another Story" is logged too', (
    tester,
  ) async {
    usePhone(tester);
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;

    // Opened from a dashboard, as in the app, so the finished screen has
    // somewhere to unwind to.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StoryFlowScreen(childId: '1'),
                ),
              ),
              child: const Text('DASHBOARD'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();

    await completeFlow(tester);
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Create Another Story');
    await completeFlow(tester);
    await tester.pumpAndSettle();

    final docs = await activityDocs(fb.firestore, '1');
    expect(docs.map((d) => d['type']), ['story_created', 'story_created']);
    final coins = await ledgerDocs(fb.firestore, '1');
    expect(coins, hasLength(2));
    expect(await fb.coins.balance('1'), CoinService.coinsPerStory * 2);
  });

  group('Beginning or Advanced writer', () {
    /// Opens the flow from a stand-in dashboard, with every service on fakes.
    Future<({dynamic fb})> openFlow(WidgetTester tester) async {
      usePhone(tester);
      final fb = signedIn();
      ActivityService.instance = fb.activity;
      CoinService.instance = fb.coins;
      StoryStore.instance = StoryStore(firestore: fb.firestore, auth: fb.auth);
      addTearDown(() => StoryStore.instance = StoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StoryFlowScreen(childId: '1'),
                  ),
                ),
                child: const Text('DASHBOARD'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('DASHBOARD'));
      await tester.pumpAndSettle();
      return (fb: fb);
    }

    Future<void> toChooser(WidgetTester tester) async {
      await tapVisible(tester, 'Next');
      await tapVisible(tester, 'Forest');
      await tapVisible(tester, 'Next');
      await tapVisible(tester, 'Funny');
      await tapVisible(tester, 'Next');
      await tester.enterText(find.byType(TextField), 'Robin');
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Start Reading!');
    }

    Future<void> typeInto(WidgetTester tester, String key, String text) async {
      final field = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }

    testWidgets('"Start Reading!" asks which writer, and Back keeps the name', (
      tester,
    ) async {
      final (:fb) = await openFlow(tester);
      await toChooser(tester);

      expect(find.byType(StoryModeScreen), findsOneWidget);
      expect(find.byType(StoryReaderScreen), findsNothing);
      // Nothing is logged until a writer is picked.
      expect(await activityDocs(fb.firestore, '1'), isEmpty);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(StorySummaryScreen), findsOneWidget);
      expect(find.text('Robin'), findsWidgets);
    });

    testWidgets('backing out of Advanced still lets them pick Beginning', (
      tester,
    ) async {
      final (:fb) = await openFlow(tester);
      await toChooser(tester);

      await tapVisible(tester, 'Advanced writer');
      expect(find.byType(StoryWriterScreen), findsOneWidget);
      await typeInto(tester, 'story-free', 'Half a story');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(StoryModeScreen), findsOneWidget);
      // The draft was kept, but it is not a finished story.
      final drafts = await fb.firestore
          .collection('parents/parent-1/children/1/stories')
          .get();
      expect(drafts.docs.single['completedAt'], isNull);
      expect(await activityDocs(fb.firestore, '1'), isEmpty);

      await tapVisible(tester, 'Beginning writer');
      expect(find.byType(StoryReaderScreen), findsOneWidget);
      final docs = await activityDocs(fb.firestore, '1');
      expect(docs.single['type'], 'story_created');
      await tester.pumpAndSettle();
      expect(await ledgerDocs(fb.firestore, '1'), hasLength(1));
    });

    testWidgets('a finished Advanced story is saved, logged, paid and shown', (
      tester,
    ) async {
      final (:fb) = await openFlow(tester);
      await toChooser(tester);
      await tapVisible(tester, 'Advanced writer');

      await typeInto(tester, 'story-title', 'Forest Fun');
      await typeInto(tester, 'story-free', 'Robin found a giggling tree.');
      await tapVisible(tester, "I'm done!");
      await tester.pumpAndSettle();

      final stories = await fb.firestore
          .collection('parents/parent-1/children/1/stories')
          .get();
      expect(stories.docs, hasLength(1));
      final story = stories.docs.single.data();
      expect(story['completedAt'], isNotNull);
      expect(story['heroName'], 'Robin');
      expect(story['setting'], 'Forest');
      expect(story['mood'], 'Funny');

      final docs = await activityDocs(fb.firestore, '1');
      expect(docs, hasLength(1));
      expect(docs.single['type'], 'story_created');
      expect(docs.single['title'], 'Forest Fun');
      final coins = await ledgerDocs(fb.firestore, '1');
      expect(coins.single['reason'], 'story');
      expect(coins.single['title'], 'Forest Fun');
      expect(find.text('🪙 +5 coins!'), findsOneWidget);

      expect(find.byType(MyStoryScreen), findsOneWidget);
      expect(find.text('Robin found a giggling tree.'), findsOneWidget);

      // The coin toast is still up; the button must not be under it.
      expect(find.text('🪙 +5 coins!'), findsOneWidget);
      await tapVisible(tester, 'The End');
      // The finished screen's buttons are under the toast until it goes.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Return Home');
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.byType(MyStoryScreen), findsNothing);
    });

    testWidgets('an untitled Advanced story is logged under the picks', (
      tester,
    ) async {
      final (:fb) = await openFlow(tester);
      await toChooser(tester);
      await tapVisible(tester, 'Advanced writer');
      await typeInto(tester, 'story-free', 'A short one.');
      await tapVisible(tester, "I'm done!");

      final docs = await activityDocs(fb.firestore, '1');
      expect(docs.single['title'], 'Robin in Forest');
      expect(find.text(StoryDraft.defaultTitle), findsWidgets);
    });
  });
}
