// Centralized reading-activity tracking layer.
//
// Every screen that needs to record or read a child's activity (reading
// module, comprehension quiz, story creation, parent dashboard) should go
// through this service instead of touching Firestore directly. This keeps the
// storage path and event shape in one place so the parent dashboard can trust
// what it reads.
//
// Storage: Firestore, one document per event at
// `parents/{uid}/children/{childId}/activity/{autoId}`. Children have no
// Firebase identity of their own, so `uid` is the signed-in parent (see
// `firestore.rules`). Each event always has `type` and `ts` (epoch millis).
// Other fields depend on `type`:
//   book_opened          {title}
//   book_finished        {title}
//   reading_session      {title, minutes, bookType}   // time spent reading
//   comprehension_result {title, chapter, score, correct, total}
//   story_created        {title}
//
// One document per event (rather than one array per child) means writes never
// read-modify-write, so concurrent logs for the same child cannot clobber each
// other.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_changes.dart';

class ActivityEvent {
  final String type;
  final int ts;
  final Map<String, dynamic> data;

  ActivityEvent({required this.type, required this.ts, required this.data});

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    final type = map.remove('type') as String? ?? 'unknown';
    final ts = (map.remove('ts') as num?)?.toInt() ?? 0;
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
      // Coin ledger rows, merged into the feed (see CoinTransaction).
      'coins_earned' => switch (data['reason']) {
        'story' =>
          '$childName earned ${data['coins']} coins for creating "$title"',
        _ => '$childName earned ${data['coins']} coins for a quiz on "$title"',
      },
      'reward_redeemed' =>
        '$childName redeemed "$title" for ${data['coins']} coins',
      'coins_refunded' =>
        '$childName got ${data['coins']} coins back for "$title"',
      _ => '$childName: $type — "$title"',
    };
  }
}

class ChildActivityStats {
  final int booksFinished;
  final int minutesThisWeek;
  final int storiesCreated;
  final double? lastComprehensionScorePct;

  /// Title of the book the child has open and not yet finished, if any.
  final String? currentlyReading;

  const ChildActivityStats({
    required this.booksFinished,
    required this.minutesThisWeek,
    required this.storiesCreated,
    required this.lastComprehensionScorePct,
    this.currentlyReading,
  });
}

class ActivityService {
  ActivityService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance the screens use. Assignable only so tests can point it
  /// at in-memory fakes before any screen touches Firebase.
  static ActivityService instance = ActivityService();

  // Resolved lazily: constructing the default instance must not touch
  // Firebase, which is not initialized in tests.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _collectionFor(String childId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('parents')
        .doc(uid)
        .collection('children')
        .doc(childId)
        .collection('activity');
  }

  /// Records one event. Silently skipped when no parent is signed in: logging
  /// is fire-and-forget from widget lifecycle hooks, where a throw would only
  /// surface as an unhandled async error.
  Future<void> logEvent(
    String childId,
    String type,
    Map<String, dynamic> data,
  ) async {
    final collection = _collectionFor(childId);
    if (collection == null) return;
    await collection.add({
      ...data,
      'type': type,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Fires whenever a new event lands for [childId], whichever device wrote
  /// it.
  Stream<void> changes(String childId) {
    final collection = _collectionFor(childId);
    if (collection == null) return const Stream.empty();
    return changesOf(collection.snapshots());
  }

  /// All of a child's events, oldest first. Empty when signed out.
  Future<List<ActivityEvent>> getEvents(String childId) async {
    final collection = _collectionFor(childId);
    if (collection == null) return [];
    final snapshot = await collection.orderBy('ts').get();
    return [
      for (final doc in snapshot.docs) ActivityEvent.fromJson(doc.data()),
    ];
  }

  /// Convenience: start a reading session timer. Call [logReadingSession]
  /// with the returned DateTime when the session ends to record minutes.
  DateTime startSession() => DateTime.now();

  Future<void> logReadingSession(
    String childId, {
    required DateTime start,
    required String title,
    required String bookType,
  }) async {
    final minutes = DateTime.now().difference(start).inMinutes;
    // Ignore sub-minute sessions (e.g. immediately closing a book) so the
    // parent dashboard doesn't fill up with noise.
    if (minutes <= 0) return;
    await logEvent(childId, 'reading_session', {
      'title': title,
      'minutes': minutes,
      'bookType': bookType,
    });
  }

  Future<ChildActivityStats> getStats(String childId) async =>
      statsFrom(await getEvents(childId));

  /// Derives the parent-facing stats from an already-fetched event list, so
  /// screens that also show the feed only read Firestore once.
  static ChildActivityStats statsFrom(List<ActivityEvent> events) {
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
          (minutes, e) => minutes + ((e.data['minutes'] as num?)?.toInt() ?? 0),
        );

    final storiesCreated = events
        .where((e) => e.type == 'story_created')
        .length;

    final sorted = [...events]..sort((a, b) => a.ts.compareTo(b.ts));

    double? lastScorePct;
    final lastComprehension = sorted
        .where((e) => e.type == 'comprehension_result')
        .lastOrNull;
    if (lastComprehension != null) {
      final correct = (lastComprehension.data['correct'] as num?)?.toDouble();
      final total = (lastComprehension.data['total'] as num?)?.toDouble();
      if (correct != null && total != null && total > 0) {
        lastScorePct = (correct / total) * 100;
      }
    }

    // The latest opened book, unless it has been finished since.
    String? currentlyReading;
    final lastOpened = sorted.where((e) => e.type == 'book_opened').lastOrNull;
    if (lastOpened != null) {
      final title = lastOpened.data['title'] as String?;
      final finishedSince = sorted.any(
        (e) =>
            e.type == 'book_finished' &&
            e.data['title'] == title &&
            e.ts >= lastOpened.ts,
      );
      if (!finishedSince) currentlyReading = title;
    }

    return ChildActivityStats(
      booksFinished: booksFinished,
      minutesThisWeek: minutesThisWeek,
      storiesCreated: storiesCreated,
      lastComprehensionScorePct: lastScorePct,
      currentlyReading: currentlyReading,
    );
  }
}
