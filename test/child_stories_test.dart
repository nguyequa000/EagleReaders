import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/screens/my_story_screen.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/screens/story_saving.dart';
import 'package:storysprout/screens/story_writer_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/story_generator.dart';
import 'package:storysprout/services/story_store.dart';

import 'test_helpers.dart';

const _config = StoryConfig(
  hero: HeroConfig(character: 'robot', name: 'Robin', pose: 'jump'),
  mood: 'Calm',
  setting: 'Ocean',
  idea: 'A shell that sings.',
);

Story _chapter(List<String> pages, {List<String> choices = const []}) =>
    Story(title: 'Robin and the Shell', pages: pages, choices: choices);

void main() {
  late FakeFirebaseFirestore firestore;
  late StoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final fb = signedIn();
    firestore = fb.firestore;
    store = StoryStore(firestore: fb.firestore, auth: fb.auth);
    StoryStore.instance = store;
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;
    FamilySettings.instance = FamilySettings(
      firestore: fb.firestore,
      auth: fb.auth,
    );
  });
  tearDown(() {
    StoryStore.instance = StoryStore();
    FamilySettings.instance = FamilySettings();
  });

  CollectionReference<Map<String, dynamic>> stories() =>
      firestore.collection('parents/parent-1/children/1/stories');

  group('store', () {
    test('the whole config survives a save', () {
      final back = storyConfigFromMap(storyConfigToMap(_config));
      expect(back.hero.character, 'robot');
      expect(back.hero.name, 'Robin');
      expect(back.hero.pose, 'jump');
      expect(back.mood, 'Calm');
      expect(back.setting, 'Ocean');
      expect(back.idea, 'A shell that sings.');
    });

    test('AI stories are listed, and a finished one stays finished', () async {
      final id = await store.saveAiStory('1', {
        'title': 'Robin and the Shell',
        'pages': ['One.', 'Two.'],
        'page': 1,
        'chapters': 1,
        'config': storyConfigToMap(_config),
      }, completed: false);
      var listed = (await store.loadStories('1')).single;
      expect(listed.byAi, isTrue);
      expect(listed.completed, isFalse);
      expect(listed.pages, ['One.', 'Two.']);
      expect(listed.page, 1);
      expect(listed.config.hero.name, 'Robin');

      await store.saveAiStory('1', {'page': 2}, id: id, completed: true);
      // e.g. the reader closing afterwards.
      await store.saveAiStory('1', {'page': 0}, id: id, completed: false);
      listed = (await store.loadStories('1')).single;
      expect(listed.completed, isTrue);
      expect(listed.page, 0);
    });

    test('older Advanced drafts without a config still rebuild one', () async {
      await stories().add({
        'title': 'Old',
        'writerLevel': 'advanced',
        'hero': 'scout',
        'heroName': 'Sam',
        'mood': 'Funny',
        'setting': 'City',
        'completedAt': null,
      });
      final story = (await store.loadStories('1')).single;
      expect(story.config.hero.character, 'scout');
      expect(story.config.hero.name, 'Sam');
      expect(story.config.setting, 'City');
    });
  });

  test('the saver creates one story and keeps updating it', () async {
    final saver = AiStorySaver(childId: '1', config: _config);
    saver.save(
      StoryProgress(
        story: _chapter(['One.'], choices: ['Swim']),
        page: 0,
        chapters: 1,
        finished: false,
      ),
    );
    saver.save(
      StoryProgress(
        story: _chapter(['One.', 'Two.']),
        page: 1,
        chapters: 2,
        finished: true,
      ),
    );
    saver.save(
      StoryProgress(
        story: _chapter(['One.', 'Two.']),
        page: 0,
        chapters: 2,
        finished: false,
      ),
    );
    await saver.settled;

    final docs = (await stories().get()).docs;
    expect(docs, hasLength(1));
    final doc = docs.single.data();
    expect(doc['writerLevel'], 'beginning');
    expect(doc['text'], 'One.\n\nTwo.');
    expect(doc['chapters'], 2);
    expect(doc['completedAt'], isNotNull);
  });

  group('reader', () {
    testWidgets('a saved story reopens at its page without writing anew', (
      tester,
    ) async {
      final progress = <StoryProgress>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StoryReaderScreen(
            config: _config,
            generate: (_, {soFar, choice}) =>
                throw StateError('should not write a new story'),
            initialStory: _chapter(['Page one.', 'Page two.', 'Page three.']),
            initialPage: 2,
            initialChapters: 2,
            onProgress: progress.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page 3 of 3'), findsOneWidget);
      expect(find.text('Page three.'), findsOneWidget);

      await tester.tap(find.text('The End'));
      await tester.pumpAndSettle();
      expect(progress.last.finished, isTrue);
      expect(progress.last.chapters, 2);
    });

    testWidgets('a new story is reported as written and on closing', (
      tester,
    ) async {
      final progress = <StoryProgress>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StoryReaderScreen(
            config: _config,
            generate: (_, {soFar, choice}) async =>
                _chapter(['A.', 'B.'], choices: ['Go on']),
            onProgress: progress.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(progress, hasLength(1));
      expect(progress.single.finished, isFalse);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(progress.last.page, 1);
      expect(progress.last.finished, isFalse);
    });
  });

  testWidgets('an Advanced draft reopens with its words and finishes once', (
    tester,
  ) async {
    final id = await store.saveDraft(
      '1',
      StoryDraft.guided(
        title: 'Sea Day',
        beginning: 'Robin swam.',
        middle: '',
        end: '',
        hero: 'robot',
        config: storyConfigToMap(_config),
        ideasShown: 2,
      ),
    );
    final draft = (await store.loadStories('1')).single;

    final results = <SavedStory?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<SavedStory>(
                MaterialPageRoute(
                  builder: (_) => StoryWriterScreen(
                    config: draft.config,
                    childId: '1',
                    resume: draft,
                  ),
                ),
              ),
            ),
            child: const Text('HOST'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('HOST'));
    await tester.pumpAndSettle();

    expect(find.text('Sea Day'), findsOneWidget);
    expect(find.text('Robin swam.'), findsOneWidget);
    expect(find.text('1 of 3 parts written'), findsOneWidget);

    await tester.ensureVisible(find.text("I'm done!"));
    await tester.tap(find.text("I'm done!"));
    await tester.pumpAndSettle();
    expect(results.single!.id, id);
    final docs = (await stories().get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single['completedAt'], isNotNull);
  });

  group('dashboard', () {
    Future<void> pumpDashboard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: ChildDashboardScreen(childId: '1', childName: 'Mika'),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<String> finished(String title, {bool ai = false}) async {
      final id = ai
          ? await store.saveAiStory('1', {
              'title': title,
              'text': 'Once upon a time.',
              'pages': ['Once upon a time.'],
              'config': storyConfigToMap(_config),
            }, completed: true)
          : (await store.complete(
              '1',
              StoryDraft.free(
                title: title,
                text: 'Once upon a time.',
                hero: 'robot',
                config: storyConfigToMap(_config),
              ),
            )).id;
      return id;
    }

    testWidgets('no finished stories: a grey plus card starts one', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(find.text('My Stories'), findsOneWidget);
      expect(find.byKey(const Key('new-story-card')), findsOneWidget);
      expect(find.byKey(const Key('no-unfinished-stories')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('new-story-card')));
      await tester.tap(find.byKey(const Key('new-story-card')));
      await tester.pumpAndSettle();
      expect(find.byType(StoryFlowScreen), findsOneWidget);
    });

    testWidgets(
      'finished stories in My Stories, the rest still being worked on',
      (tester) async {
        await finished('The Big Wave', ai: true);
        await finished('Robin Builds a Boat');
        await store.saveDraft(
          '1',
          StoryDraft.free(
            title: 'Half a Tale',
            text: 'It began',
            hero: 'robot',
            config: storyConfigToMap(_config),
          ),
        );
        await pumpDashboard(tester);

        expect(find.byKey(const Key('new-story-card')), findsNothing);
        expect(find.text('The Big Wave'), findsOneWidget);
        expect(find.text('With Sprout'), findsOneWidget);
        expect(find.text('Robin Builds a Boat'), findsOneWidget);
        expect(find.text('By you'), findsOneWidget);
        expect(find.text('Half a Tale'), findsOneWidget);
        expect(find.text('Keep writing'), findsOneWidget);

        double y(String text) => tester.getTopLeft(find.text(text)).dy;
        expect(y('Robin Builds a Boat'), lessThan(y('Still Working On')));
        expect(y('Half a Tale'), greaterThan(y('Still Working On')));
        expect(y('Story Ideas'), greaterThan(y('Half a Tale')));
      },
    );

    testWidgets('a finished story opens to read', (tester) async {
      await finished('Robin Builds a Boat');
      await pumpDashboard(tester);
      await tester.ensureVisible(find.text('Robin Builds a Boat'));
      await tester.tap(find.text('Robin Builds a Boat'));
      await tester.pumpAndSettle();
      expect(find.byType(MyStoryScreen), findsOneWidget);
      expect(find.text('Once upon a time.'), findsOneWidget);
    });

    testWidgets('finishing a draft from the dashboard logs it and pays', (
      tester,
    ) async {
      await store.saveDraft(
        '1',
        StoryDraft.free(
          title: 'Half a Tale',
          text: 'It began and then it ended.',
          hero: 'robot',
          config: storyConfigToMap(_config),
        ),
      );
      await pumpDashboard(tester);
      await tester.ensureVisible(find.text('Half a Tale'));
      await tester.tap(find.text('Half a Tale'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryWriterScreen), findsOneWidget);
      expect(find.text('It began and then it ended.'), findsOneWidget);

      await tester.ensureVisible(find.text("I'm done!"));
      await tester.tap(find.text("I'm done!"));
      await tester.pumpAndSettle();
      expect(find.byType(MyStoryScreen), findsOneWidget);

      final fb = (await activityDocs(firestore, '1'));
      expect(fb.single['type'], 'story_created');
      expect(fb.single['title'], 'Half a Tale');
      expect((await ledgerDocs(firestore, '1')).single['reason'], 'story');

      // Back home, it has moved to My Stories.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The End'));
      await tester.pumpAndSettle();
      expect(find.text('Keep writing'), findsNothing);
      expect(find.text('By you'), findsOneWidget);
    });

    testWidgets('an unfinished Sprout story picks up where it was', (
      tester,
    ) async {
      await store.saveAiStory('1', {
        'title': 'The Big Wave',
        'pages': ['One.', 'Two.'],
        'choices': ['Surf', 'Dive'],
        'page': 1,
        'chapters': 1,
        'config': storyConfigToMap(_config),
      }, completed: false);
      await pumpDashboard(tester);
      expect(find.text('Keep reading'), findsOneWidget);

      await tester.ensureVisible(find.text('The Big Wave'));
      await tester.tap(find.text('The Big Wave'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryReaderScreen), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.text('Surf'), findsOneWidget);
    });

    testWidgets('story ideas go when AI stories are off', (tester) async {
      await FamilySettings.instance.save(const AiSettings(aiStories: false));
      await pumpDashboard(tester);
      expect(find.text('Story Ideas'), findsNothing);
      expect(find.text('My Stories'), findsOneWidget);
      expect(find.text('Still Working On'), findsOneWidget);
    });
  });

  testWidgets('a Beginning story from the flow is saved as Sprout writes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: StoryFlowScreen(childId: '1')),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tap('Next');
    await tap('Forest');
    await tap('Next');
    await tap('Funny');
    await tap('Next');
    await tap('Start Reading!');
    await tap('Beginning writer');
    // No AI in tests: the offline classic shows, which isn't saved.
    expect(find.text('Try again'), findsOneWidget);
    expect((await stories().get()).docs, isEmpty);
  });
}
