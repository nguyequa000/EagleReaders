import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A story the child is writing in Advanced writer mode.
///
/// Free mode fills [text]; guided mode fills [beginning], [middle] and [end],
/// and [text] is the three joined so the reader and the parent view have one
/// field to read.
class StoryDraft {
  static const defaultTitle = 'My Story';

  final String title;

  /// `'free'` or `'guided'`.
  final String mode;
  final String text;
  final String? beginning;
  final String? middle;
  final String? end;

  /// The hero key (`HeroConfig.effectiveCharacter`).
  final String hero;

  /// The name typed on the summary, if any. Stored for the parent; never sent
  /// to Sprout.
  final String? heroName;
  final String? mood;
  final String? setting;

  /// How many times Sprout gave an idea.
  final int ideasShown;

  const StoryDraft({
    required this.title,
    required this.mode,
    required this.text,
    this.beginning,
    this.middle,
    this.end,
    required this.hero,
    this.heroName,
    this.mood,
    this.setting,
    this.ideasShown = 0,
  });

  /// Free mode: one notepad.
  factory StoryDraft.free({
    required String title,
    required String text,
    required String hero,
    String? heroName,
    String? mood,
    String? setting,
    int ideasShown = 0,
  }) => StoryDraft(
    title: title,
    mode: 'free',
    text: text.trim(),
    hero: hero,
    heroName: heroName,
    mood: mood,
    setting: setting,
    ideasShown: ideasShown,
  );

  /// Guided mode: beginning, middle and end.
  factory StoryDraft.guided({
    required String title,
    required String beginning,
    required String middle,
    required String end,
    required String hero,
    String? heroName,
    String? mood,
    String? setting,
    int ideasShown = 0,
  }) {
    final parts = [beginning, middle, end].map((p) => p.trim());
    return StoryDraft(
      title: title,
      mode: 'guided',
      text: parts.where((p) => p.isNotEmpty).join('\n\n'),
      beginning: beginning.trim(),
      middle: middle.trim(),
      end: end.trim(),
      hero: hero,
      heroName: heroName,
      mood: mood,
      setting: setting,
      ideasShown: ideasShown,
    );
  }

  String get effectiveTitle =>
      title.trim().isEmpty ? defaultTitle : title.trim();

  int get totalWords => countWords(text);

  bool get isEmpty => text.trim().isEmpty && title.trim().isEmpty;

  static int countWords(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  Map<String, dynamic> toMap() => {
    'title': effectiveTitle,
    'mode': mode,
    'writerLevel': 'advanced',
    'hero': hero,
    'heroName': heroName,
    'mood': mood,
    'setting': setting,
    'text': text,
    'beginning': beginning,
    'middle': middle,
    'end': end,
    'totalWords': totalWords,
    'ideasShown': ideasShown,
  };
}

/// A finished story, as the writer hands it back to the flow.
class SavedStory {
  /// The Firestore id, or empty when nothing was saved (no child, dev entry).
  final String id;
  final String title;
  final String text;

  const SavedStory({required this.id, required this.title, required this.text});
}

/// Children's own stories, at `parents/{uid}/children/{childId}/stories/{id}`.
///
/// Covered by the `parents/{uid}/**` rule, so no rules change. Same shape as
/// `CoinService`: optional injected Firebase, resolved lazily so the default
/// instance can exist in tests, and writes throw [StateError] when signed out.
class StoryStore {
  StoryStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance the screens use. Assignable only so tests can point it
  /// at in-memory fakes before any screen touches Firebase.
  static StoryStore instance = StoryStore();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _stories(String childId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Cannot save a story while signed out.');
    }
    return _firestore
        .collection('parents')
        .doc(uid)
        .collection('children')
        .doc(childId)
        .collection('stories');
  }

  /// Creates the draft, or updates it when [id] is given. Returns the id.
  Future<String> saveDraft(String childId, StoryDraft draft, {String? id}) =>
      _write(childId, draft, id: id, completed: false);

  /// Saves the story as finished (sets `completedAt`).
  Future<SavedStory> complete(
    String childId,
    StoryDraft draft, {
    String? id,
  }) async {
    final savedId = await _write(childId, draft, id: id, completed: true);
    return SavedStory(
      id: savedId,
      title: draft.effectiveTitle,
      text: draft.text,
    );
  }

  Future<String> _write(
    String childId,
    StoryDraft draft, {
    String? id,
    required bool completed,
  }) async {
    final stories = _stories(childId);
    final doc = id == null ? stories.doc() : stories.doc(id);
    final now = FieldValue.serverTimestamp();
    await doc.set({
      ...draft.toMap(),
      // Only on the first write: merge would otherwise move it forward.
      if (id == null) 'createdAt': now,
      'updatedAt': now,
      'completedAt': completed ? now : null,
    }, SetOptions(merge: true));
    return doc.id;
  }
}
