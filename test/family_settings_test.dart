import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/family_settings.dart';
import 'package:storysprout/services/reader_audience.dart';

import 'test_helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late ChildProfileStore store;
  late FamilySettings settings;

  setUp(() {
    final fb = signedIn();
    firestore = fb.firestore;
    auth = fb.auth;
    store = fb.store;
    settings = FamilySettings(firestore: firestore, auth: auth);
  });

  test('never-set settings load as the defaults', () async {
    final ai = await settings.load();
    expect(ai.aiStories, isTrue);
    expect(ai.aiQuizzes, isTrue);
    expect(ai.sproutIdeas, isTrue);
    expect(ai.readAloud, isTrue);
    expect(ai.readingReminder, isFalse);
  });

  test('switches round-trip and are cached for the screens', () async {
    await settings.save(
      const AiSettings(aiQuizzes: false, readingReminder: true),
    );
    expect(settings.ai.aiQuizzes, isFalse);

    final fresh = FamilySettings(firestore: firestore, auth: auth);
    final ai = await fresh.load();
    expect(ai.aiQuizzes, isFalse);
    expect(ai.readingReminder, isTrue);
    expect(ai.aiStories, isTrue);
    expect(fresh.ai.aiQuizzes, isFalse);
  });

  test('saving settings keeps the rest of the parent document', () async {
    await firestore.doc('parents/parent-1').set({'email': 'p@x.com'});
    await settings.save(const AiSettings(sproutIdeas: false));
    final doc = (await firestore.doc('parents/parent-1').get()).data()!;
    expect(doc['email'], 'p@x.com');
    expect(doc['settings']['sproutIdeas'], isFalse);
  });

  test('the display name is saved and read back trimmed', () async {
    expect(await settings.loadDisplayName(), isNull);
    await settings.saveDisplayName('  Sam  ');
    expect(await settings.loadDisplayName(), 'Sam');
    expect(auth.currentUser!.displayName, 'Sam');
  });

  test('child rules survive a profile save', () async {
    final mika = ChildProfile.withPin(id: 'kid-1', name: 'Mika', pin: '1234');
    await store.save([mika]);
    await settings.saveChild(
      'kid-1',
      const ChildRules(ageBand: AgeBand.ages3to5, dailyLimitMinutes: 30),
    );
    // e.g. the parent renames the child afterwards.
    await store.save([
      ChildProfile.withPin(id: 'kid-1', name: 'Mika B', pin: '1234'),
    ]);

    final rules = await settings.loadChild('kid-1');
    expect(rules.ageBand, AgeBand.ages3to5);
    expect(rules.dailyLimitMinutes, 30);

    await settings.saveChild('kid-1', const ChildRules());
    expect((await settings.loadChild('kid-1')).dailyLimitMinutes, isNull);
  });

  test('the limit stops at the limit, and a grown-up can lift it', () async {
    final now = DateTime(2026, 10, 9, 15);
    const rules = ChildRules(dailyLimitMinutes: 20);
    expect(rules.limitReached(19, now), isFalse);
    expect(rules.limitReached(20, now), isTrue);
    expect(const ChildRules().limitReached(500, now), isFalse);

    await settings.unlockToday('kid-1', now: now);
    final unlocked = await settings.loadChild('kid-1');
    expect(unlocked.limitUnlockedOn, '2026-10-09');
    final withLimit = ChildRules(
      dailyLimitMinutes: 20,
      limitUnlockedOn: unlocked.limitUnlockedOn,
    );
    expect(withLimit.limitReached(60, now), isFalse);
    // The unlock is for that day only.
    expect(withLimit.limitReached(60, DateTime(2026, 10, 10, 9)), isTrue);
  });

  test("today's minutes and reading ignore other days and other events", () {
    final now = DateTime(2026, 10, 9, 18);
    ActivityEvent event(String type, DateTime when, [int minutes = 0]) =>
        ActivityEvent(
          type: type,
          ts: when.millisecondsSinceEpoch,
          data: {'minutes': minutes},
        );
    final events = [
      event('reading_session', DateTime(2026, 10, 8, 20), 40),
      event('reading_session', DateTime(2026, 10, 9, 8), 10),
      event('reading_session', DateTime(2026, 10, 9, 17), 7),
      event('story_created', DateTime(2026, 10, 9, 12)),
    ];
    expect(minutesReadToday(events, now), 17);
    expect(readToday(events, now), isTrue);
    expect(readToday(events.take(1).toList(), now), isFalse);
    expect(
      readToday([event('story_created', DateTime(2026, 10, 9, 9))], now),
      isFalse,
    );
    expect(
      readToday([event('book_opened', DateTime(2026, 10, 9, 9))], now),
      isTrue,
    );
  });

  test('signed out: defaults to read, writes refused', () async {
    final out = FamilySettings(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: false),
    );
    expect((await out.load()).aiStories, isTrue);
    expect((await out.loadChild('kid-1')).dailyLimitMinutes, isNull);
    expect(await out.loadDisplayName(), isNull);
    expect(() => out.save(const AiSettings()), throwsStateError);
    expect(() => out.saveChild('kid-1', const ChildRules()), throwsStateError);
    expect(() => out.unlockToday('kid-1'), throwsStateError);
  });
}
