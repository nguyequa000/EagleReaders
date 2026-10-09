import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_service.dart';
import 'firestore_changes.dart';
import 'reader_audience.dart';

/// The parent's switches from Parent Settings, for the whole family.
class AiSettings {
  /// Gemini writes stories (the Beginning writer and the dashboard presets).
  final bool aiStories;

  /// Gemini writes the chapter, end-of-book and end-of-story quizzes.
  final bool aiQuizzes;

  /// Sprout's idea questions in the Advanced writer (an offline list, not AI,
  /// but the parent may still want the child writing unprompted).
  final bool sproutIdeas;

  /// The story reader's Read aloud button.
  final bool readAloud;

  /// The child dashboard nudges a child who hasn't read today.
  final bool readingReminder;

  const AiSettings({
    this.aiStories = true,
    this.aiQuizzes = true,
    this.sproutIdeas = true,
    this.readAloud = true,
    this.readingReminder = false,
  });

  factory AiSettings.fromMap(Map<String, dynamic>? map) {
    const defaults = AiSettings();
    bool read(String key, bool fallback) =>
        map?[key] is bool ? map![key] as bool : fallback;
    return AiSettings(
      aiStories: read('aiStories', defaults.aiStories),
      aiQuizzes: read('aiQuizzes', defaults.aiQuizzes),
      sproutIdeas: read('sproutIdeas', defaults.sproutIdeas),
      readAloud: read('readAloud', defaults.readAloud),
      readingReminder: read('readingReminder', defaults.readingReminder),
    );
  }

  Map<String, dynamic> toMap() => {
    'aiStories': aiStories,
    'aiQuizzes': aiQuizzes,
    'sproutIdeas': sproutIdeas,
    'readAloud': readAloud,
    'readingReminder': readingReminder,
  };

  AiSettings copyWith({
    bool? aiStories,
    bool? aiQuizzes,
    bool? sproutIdeas,
    bool? readAloud,
    bool? readingReminder,
  }) => AiSettings(
    aiStories: aiStories ?? this.aiStories,
    aiQuizzes: aiQuizzes ?? this.aiQuizzes,
    sproutIdeas: sproutIdeas ?? this.sproutIdeas,
    readAloud: readAloud ?? this.readAloud,
    readingReminder: readingReminder ?? this.readingReminder,
  );
}

/// One child's age band and daily reading limit.
class ChildRules {
  final AgeBand ageBand;

  /// Minutes of reading a day, or null for no limit.
  final int? dailyLimitMinutes;

  /// The day (`yyyy-MM-dd`) a grown-up lifted the limit, if any.
  final String? limitUnlockedOn;

  const ChildRules({
    this.ageBand = AgeBand.fallback,
    this.dailyLimitMinutes,
    this.limitUnlockedOn,
  });

  factory ChildRules.fromMap(Map<String, dynamic>? map) => ChildRules(
    ageBand: AgeBand.fromName(map?['ageBand'] as String?),
    dailyLimitMinutes: (map?['dailyLimitMinutes'] as num?)?.toInt(),
    limitUnlockedOn: map?['limitUnlockedOn'] as String?,
  );

  /// Whether the limit stops reading on [now]'s day, after [minutesToday].
  bool limitReached(int minutesToday, DateTime now) {
    final limit = dailyLimitMinutes;
    if (limit == null || limitUnlockedOn == dayKey(now)) return false;
    return minutesToday >= limit;
  }
}

/// `yyyy-MM-dd` in local time: what "today" means to a child.
String dayKey(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-'
    '${time.month.toString().padLeft(2, '0')}-'
    '${time.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes of reading logged on [now]'s day.
int minutesReadToday(List<ActivityEvent> events, DateTime now) {
  var minutes = 0;
  for (final event in events) {
    if (event.type != 'reading_session' || !_sameDay(event.dateTime, now)) {
      continue;
    }
    minutes += (event.data['minutes'] as num?)?.toInt() ?? 0;
  }
  return minutes;
}

/// Whether the child opened or read a book on [now]'s day.
bool readToday(List<ActivityEvent> events, DateTime now) => events.any(
  (e) =>
      (e.type == 'book_opened' || e.type == 'reading_session') &&
      _sameDay(e.dateTime, now),
);

/// Parent Settings, kept in Firestore so every device in the family sees the
/// same switches.
///
/// [AiSettings] live in a `settings` map on `parents/{uid}`; [ChildRules] are
/// fields on each child's document, which `ChildProfileStore.save()` keeps
/// because it writes with merge (like `coinBalance`).
class FamilySettings {
  FamilySettings({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance the screens use. Assignable only so tests can point it
  /// at in-memory fakes before any screen touches Firebase.
  static FamilySettings instance = FamilySettings();

  // Resolved lazily, like CoinService: constructing the default instance must
  // not touch Firebase, which is not initialized in tests.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// The switches as last loaded or saved on this device.
  ///
  /// The story and reading screens read this rather than taking it as an
  /// argument, so it reaches them without changing every screen in between.
  /// The child dashboard refreshes it whenever it loads.
  AiSettings ai = const AiSettings();

  DocumentReference<Map<String, dynamic>>? get _parent {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _firestore.collection('parents').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _require(String what) {
    final parent = _parent;
    if (parent == null) throw StateError('Cannot $what while signed out.');
    return parent;
  }

  /// The family's switches; the defaults when signed out or never set.
  Future<AiSettings> load() async {
    final parent = _parent;
    if (parent == null) return ai = const AiSettings();
    final doc = await parent.get();
    return ai = AiSettings.fromMap(
      doc.data()?['settings'] as Map<String, dynamic>?,
    );
  }

  Future<void> save(AiSettings settings) async {
    await _require(
      'change settings',
    ).set({'settings': settings.toMap()}, SetOptions(merge: true));
    ai = settings;
  }

  /// The parent's name for the dashboard greeting, or null if never set.
  Future<String?> loadDisplayName() async {
    final parent = _parent;
    if (parent == null) return null;
    final name = (await parent.get()).data()?['displayName'] as String?;
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  /// What the dashboards greet the parent as: the name they set, else the
  /// start of their email, else null.
  Future<String?> loadGreetingName() async {
    final name = await loadDisplayName();
    if (name != null) return name;
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) return null;
    return email.split('@').first;
  }

  Future<void> saveDisplayName(String name) async {
    await _require(
      'change your name',
    ).set({'displayName': name.trim()}, SetOptions(merge: true));
    await _auth.currentUser?.updateDisplayName(name.trim());
  }

  Future<ChildRules> loadChild(String childId) async {
    final parent = _parent;
    if (parent == null) return const ChildRules();
    final doc = await parent.collection('children').doc(childId).get();
    return ChildRules.fromMap(doc.data());
  }

  /// Saves the age band and daily limit (a null limit removes it).
  Future<void> saveChild(String childId, ChildRules rules) async {
    await _require('change limits').collection('children').doc(childId).set({
      'ageBand': rules.ageBand.name,
      'dailyLimitMinutes': rules.dailyLimitMinutes,
    }, SetOptions(merge: true));
  }

  /// Lifts today's limit for [childId] (a grown-up typed the PIN).
  Future<void> unlockToday(String childId, {DateTime? now}) async {
    await _require('unlock').collection('children').doc(childId).set({
      'limitUnlockedOn': dayKey(now ?? DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// Fires when the switches or [childId]'s rules change on any device.
  Stream<void> changes({String? childId}) {
    final parent = _parent;
    if (parent == null) return const Stream.empty();
    return mergeChanges([
      changesOf(parent.snapshots()),
      if (childId != null)
        changesOf(parent.collection('children').doc(childId).snapshots()),
    ]);
  }
}
