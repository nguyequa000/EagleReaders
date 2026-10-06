// Focused unit tests for ActivityService's Firestore-backed tracking.
//
// The widget test in reader_activity_test.dart never exercises
// logReadingSession end-to-end because a widget test can't fast-forward
// real wall-clock time between "book opened" and "book closed" without
// slowing the test suite down by actual minutes. Instead we test
// ActivityService directly, injecting a `start` DateTime in the past —
// this exercises the exact same code path (logReadingSession -> logEvent)
// with real, deterministic elapsed-time math instead of mocking the clock.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/activity_service.dart';

import 'test_helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ActivityService service;

  setUp(() {
    final fb = signedIn();
    firestore = fb.firestore;
    service = fb.activity;
  });

  Future<void> seed(String childId, List<Map<String, dynamic>> events) async {
    final collection = firestore
        .collection('parents')
        .doc('parent-1')
        .collection('children')
        .doc(childId)
        .collection('activity');
    for (final event in events) {
      await collection.add(event);
    }
  }

  test('events are stored under the parent and child id', () async {
    await service.logEvent('child-1', 'book_opened', {'title': 'Alice'});

    final docs = await activityDocs(firestore, 'child-1');
    expect(docs, hasLength(1));
    expect(docs.single['type'], 'book_opened');
    expect(docs.single['title'], 'Alice');
    expect(docs.single['ts'], isA<int>());
  });

  test('logReadingSession records real elapsed minutes', () async {
    final start = DateTime.now().subtract(const Duration(minutes: 12));

    await service.logReadingSession(
      'child-1',
      start: start,
      title: 'Alice in Wonderland',
      bookType: 'epub',
    );

    final events = await service.getEvents('child-1');
    expect(events, hasLength(1));
    expect(events.single.type, 'reading_session');
    expect(events.single.data['title'], 'Alice in Wonderland');
    expect(events.single.data['bookType'], 'epub');
    // Allow +/-1 minute of slack for scheduling jitter between computing
    // `start` above and the DateTime.now() call inside logReadingSession.
    expect(events.single.data['minutes'], inInclusiveRange(11, 12));
  });

  test('sub-minute sessions are not logged (avoids dashboard noise)', () async {
    await service.logReadingSession(
      'child-1',
      start: DateTime.now(), // effectively 0 minutes elapsed
      title: 'Alice in Wonderland',
      bookType: 'epub',
    );

    expect(await service.getEvents('child-1'), isEmpty);
  });

  test(
    'getStats sums reading_session minutes within the last 7 days',
    () async {
      final now = DateTime.now();
      final recent = now.subtract(const Duration(days: 2));
      final old = now.subtract(const Duration(days: 10));

      await seed('child-1', [
        {
          'type': 'reading_session',
          'ts': recent.millisecondsSinceEpoch,
          'title': 'Book A',
          'minutes': 15,
          'bookType': 'epub',
        },
        {
          'type': 'reading_session',
          'ts': recent.millisecondsSinceEpoch,
          'title': 'Book B',
          'minutes': 20,
          'bookType': 'epub',
        },
        // Outside the 7-day window — must not be counted.
        {
          'type': 'reading_session',
          'ts': old.millisecondsSinceEpoch,
          'title': 'Old Book',
          'minutes': 999,
          'bookType': 'epub',
        },
      ]);

      final stats = await service.getStats('child-1');
      expect(stats.minutesThisWeek, 35);
    },
  );

  test('concurrent logEvent calls for the same child both land', () async {
    await Future.wait([
      service.logEvent('child-1', 'book_finished', {'title': 'Book One'}),
      service.logEvent('child-1', 'book_finished', {'title': 'Book Two'}),
    ]);

    final events = await service.getEvents('child-1');
    expect(
      events.map((e) => e.data['title']),
      unorderedEquals(['Book One', 'Book Two']),
    );
  });

  test('story_created events count towards storiesCreated', () async {
    await service.logEvent('child-1', 'story_created', {'title': 'Dragon'});
    await service.logEvent('child-1', 'story_created', {'title': 'Fox'});

    expect((await service.getStats('child-1')).storiesCreated, 2);
  });

  group('currentlyReading', () {
    test('is the latest opened book', () async {
      await seed('child-1', [
        {'type': 'book_opened', 'ts': 1, 'title': 'Alice'},
        {'type': 'book_opened', 'ts': 2, 'title': 'Peter Pan'},
      ]);
      expect((await service.getStats('child-1')).currentlyReading, 'Peter Pan');
    });

    test('clears once that book is finished', () async {
      await seed('child-1', [
        {'type': 'book_opened', 'ts': 1, 'title': 'Alice'},
        {'type': 'book_finished', 'ts': 2, 'title': 'Alice'},
      ]);
      expect((await service.getStats('child-1')).currentlyReading, isNull);
    });

    test('comes back when a finished book is reopened', () async {
      await seed('child-1', [
        {'type': 'book_opened', 'ts': 1, 'title': 'Alice'},
        {'type': 'book_finished', 'ts': 2, 'title': 'Alice'},
        {'type': 'book_opened', 'ts': 3, 'title': 'Alice'},
      ]);
      expect((await service.getStats('child-1')).currentlyReading, 'Alice');
    });

    test('is not cleared by finishing a different book', () async {
      await seed('child-1', [
        {'type': 'book_opened', 'ts': 1, 'title': 'Alice'},
        {'type': 'book_finished', 'ts': 2, 'title': 'Peter Pan'},
      ]);
      expect((await service.getStats('child-1')).currentlyReading, 'Alice');
    });
  });

  test("children's activity is kept separate", () async {
    await service.logEvent('child-1', 'book_opened', {'title': 'Alice'});

    expect(await service.getEvents('child-2'), isEmpty);
  });

  test('signed out: writes are skipped and reads are empty', () async {
    final signedOut = ActivityService(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: false),
    );

    await signedOut.logEvent('child-1', 'book_opened', {'title': 'Alice'});

    expect(await signedOut.getEvents('child-1'), isEmpty);
    expect(await activityDocs(firestore, 'child-1'), isEmpty);
  });
}
