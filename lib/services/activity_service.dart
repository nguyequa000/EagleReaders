// Centralized reading-activity tracking layer.
//
// Every screen that needs to record or read a child's activity (reading
// module, comprehension quiz, parent dashboard) should go through this
// service instead of touching SharedPreferences directly. This keeps the
// storage key format and event shape in one place so the parent dashboard
// can trust what it reads.
//
// Storage: SharedPreferences, key `activity_log_<childName>` -> JSON list of
// event maps. Each event always has `type` and `ts` (epoch millis). Other
// fields depend on `type`:
//   book_opened          {title}
//   book_finished        {title}
//   reading_session      {title, minutes, bookType}   // time spent reading
//   comprehension_result {title, chapter, score, correct, total}
//
// NOTE: child identity is currently just a display-name string (e.g.
// "Alex"). There is no child-profile id system wired in yet — this is a
// known simplification, not a design decision; revisit if/when profiles
// get real ids.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityEvent {
  final String type;
  final int ts;
  final Map<String, dynamic> data;

  ActivityEvent({required this.type, required this.ts, required this.data});

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    final type = map.remove('type') as String? ?? 'unknown';
    final ts = map.remove('ts') as int? ?? 0;
    return ActivityEvent(type: type, ts: ts, data: map);
  }

  Map<String, dynamic> toJson() => {'type': type, 'ts': ts, ...data};

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts);

  /// Parent-facing one-line summary, shared by the dashboard and profile.
  String describe(String childName) {
    final title = data['title'] ?? 'a book';
    return switch (type) {
      'book_opened' => '$childName started reading "$title"',
      'book_finished' => '$childName finished "$title"',
      'reading_session' =>
        '$childName read "$title" for ${data['minutes']} min',
      'comprehension_result' =>
        '$childName scored ${data['score'] ?? ''} on "$title"',
      'story_created' => '$childName created a new story: "$title"',
      _ => '$childName: $type — "$title"',
    };
  }
}

class ChildActivityStats {
  final int booksFinished;
  final int minutesThisWeek;
  final int storiesCreated;
  final double? lastComprehensionScorePct;

  const ChildActivityStats({
    required this.booksFinished,
    required this.minutesThisWeek,
    required this.storiesCreated,
    required this.lastComprehensionScorePct,
  });
}

class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  // Per-child write queue. logEvent does a read-modify-write against a
  // single SharedPreferences key; without serializing writes, two
  // concurrent logEvent calls for the same child (e.g. a reading_session
  // flush racing a book_finished log when a book completes) can both read
  // the pre-mutation list and the second write silently clobbers the
  // first's event. Chaining onto the previous write's future per child
  // makes each logEvent atomic relative to the others.
  final Map<String, Future<void>> _writeQueues = {};

  String _keyFor(String childName) => 'activity_log_$childName';

  Future<void> logEvent(
    String childName,
    String type,
    Map<String, dynamic> data,
  ) {
    final previous = _writeQueues[childName] ?? Future.value();
    final next = previous.then((_) => _appendEvent(childName, type, data));
    // Swallow errors here so one failed write doesn't wedge the queue for
    // subsequent callers; the error still propagates to whoever awaited
    // this specific call via the returned future.
    _writeQueues[childName] = next.catchError((_) {});
    return next;
  }

  Future<void> _appendEvent(
    String childName,
    String type,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(childName);
    final events = jsonDecode(prefs.getString(key) ?? '[]') as List<dynamic>;
    events.add({
      'type': type,
      'ts': DateTime.now().millisecondsSinceEpoch,
      ...data,
    });
    await prefs.setString(key, jsonEncode(events));
  }

  Future<List<ActivityEvent>> getEvents(String childName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        jsonDecode(prefs.getString(_keyFor(childName)) ?? '[]')
            as List<dynamic>;
    return raw
        .map((e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Convenience: start a reading session timer. Call [logReadingSession]
  /// with the returned DateTime when the session ends to record minutes.
  DateTime startSession() => DateTime.now();

  Future<void> logReadingSession(
    String childName, {
    required DateTime start,
    required String title,
    required String bookType,
  }) async {
    final minutes = DateTime.now().difference(start).inMinutes;
    // Ignore sub-minute sessions (e.g. immediately closing a book) so the
    // parent dashboard doesn't fill up with noise.
    if (minutes <= 0) return;
    await logEvent(childName, 'reading_session', {
      'title': title,
      'minutes': minutes,
      'bookType': bookType,
    });
  }

  Future<ChildActivityStats> getStats(String childName) async {
    final events = await getEvents(childName);

    final booksFinished = events
        .where((e) => e.type == 'book_finished')
        .map((e) => e.data['title'])
        .toSet()
        .length;

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final minutesThisWeek = events
        .where(
          (e) => e.type == 'reading_session' && e.dateTime.isAfter(weekAgo),
        )
        .fold<int>(
          0,
          (sum, e) => sum + ((e.data['minutes'] as num?)?.toInt() ?? 0),
        );

    final storiesCreated = events
        .where((e) => e.type == 'story_created')
        .length;

    double? lastScorePct;
    final comprehensionEvents = events
        .where((e) => e.type == 'comprehension_result')
        .toList();
    if (comprehensionEvents.isNotEmpty) {
      comprehensionEvents.sort((a, b) => a.ts.compareTo(b.ts));
      final last = comprehensionEvents.last;
      final correct = (last.data['correct'] as num?)?.toDouble();
      final total = (last.data['total'] as num?)?.toDouble();
      if (correct != null && total != null && total > 0) {
        lastScorePct = (correct / total) * 100;
      }
    }

    return ChildActivityStats(
      booksFinished: booksFinished,
      minutesThisWeek: minutesThisWeek,
      storiesCreated: storiesCreated,
      lastComprehensionScorePct: lastScorePct,
    );
  }
}
