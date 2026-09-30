// Focused unit tests for ActivityService's reading-session tracking.
//
// Follow-up to the QA review of the reading-module/tracking-layer change:
// the widget test in reader_activity_test.dart never exercises
// logReadingSession end-to-end because a widget test can't fast-forward
// real wall-clock time between "book opened" and "book closed" without
// slowing the test suite down by actual minutes. Instead we test
// ActivityService directly, injecting a `start` DateTime in the past —
// this exercises the exact same code path (logReadingSession -> logEvent)
// with real, deterministic elapsed-time math instead of mocking the clock.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/activity_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('logReadingSession records real elapsed minutes', () async {
    final start = DateTime.now().subtract(const Duration(minutes: 12));

    await ActivityService.instance.logReadingSession(
      'Alex',
      start: start,
      title: 'Alice in Wonderland',
      bookType: 'epub',
    );

    final events = await ActivityService.instance.getEvents('Alex');
    expect(events, hasLength(1));
    expect(events.single.type, 'reading_session');
    expect(events.single.data['title'], 'Alice in Wonderland');
    expect(events.single.data['bookType'], 'epub');
    // Allow +/-1 minute of slack for scheduling jitter between computing
    // `start` above and the DateTime.now() call inside logReadingSession.
    expect(events.single.data['minutes'], inInclusiveRange(11, 12));
  });

  test('sub-minute sessions are not logged (avoids dashboard noise)', () async {
    final start = DateTime.now(); // effectively 0 minutes elapsed

    await ActivityService.instance.logReadingSession(
      'Alex',
      start: start,
      title: 'Alice in Wonderland',
      bookType: 'epub',
    );

    final events = await ActivityService.instance.getEvents('Alex');
    expect(events, isEmpty);
  });

  test(
    'getStats sums reading_session minutes within the last 7 days',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final recent = now.subtract(const Duration(days: 2));
      final old = now.subtract(const Duration(days: 10));

      await prefs.setString(
        'activity_log_Alex',
        jsonEncode([
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
            'bookType': 'txt',
          },
          // Outside the 7-day window — must not be counted.
          {
            'type': 'reading_session',
            'ts': old.millisecondsSinceEpoch,
            'title': 'Old Book',
            'minutes': 999,
            'bookType': 'epub',
          },
        ]),
      );

      final stats = await ActivityService.instance.getStats('Alex');
      expect(stats.minutesThisWeek, 35);
    },
  );

  test('logEvent calls for the same child do not clobber each other', () async {
    // Regression test for the write-race found in QA review: two
    // concurrent logEvent calls for the same child used to both read the
    // pre-mutation event list and the second write would silently drop
    // the first event. Firing both without awaiting reproduces the race
    // if the write-queue serialization regresses.
    final first = ActivityService.instance.logEvent('Alex', 'book_finished', {
      'title': 'Book One',
    });
    final second = ActivityService.instance.logEvent('Alex', 'book_finished', {
      'title': 'Book Two',
    });
    await Future.wait([first, second]);

    final events = await ActivityService.instance.getEvents('Alex');
    expect(events, hasLength(2));
    expect(events.map((e) => e.data['title']), ['Book One', 'Book Two']);
  });
}
