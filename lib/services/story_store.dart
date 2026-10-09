import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/story/hero_config.dart';
import '../screens/story/story_config.dart';
import 'firestore_changes.dart';

/// Everything needed to rebuild a story's [StoryConfig] later: the writer's
/// header chips and Sprout's picks, or the AI writing the next chapter.
Map<String, dynamic> storyConfigToMap(StoryConfig config) => {
  'character': config.hero.character,
  'pose': config.hero.pose,
  'outfitColor': config.hero.outfitColor,
  'petAsset': config.hero.petAsset,
  'name': config.hero.name,
  'mood': config.mood,
  'setting': config.setting,
  'idea': config.idea,
};

StoryConfig storyConfigFromMap(Map<String, dynamic> map) => StoryConfig(
  hero: HeroConfig(
    character: map['character'] as String?,
    pose: map['pose'] as String?,
    outfitColor: map['outfitColor'] as String?,
    petAsset: map['petAsset'] as String?,
    name: map['name'] as String?,
  ),
  mood: map['mood'] as String?,
  setting: map['setting'] as String?,
  idea: map['idea'] as String? ?? '',
);

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

  /// The whole [StoryConfig], from [storyConfigToMap], so a draft can be
  /// reopened exactly as it was.
  final Map<String, dynamic>? config;

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
    this.config,
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
    Map<String, dynamic>? config,
  }) => StoryDraft(
    title: title,
    mode: 'free',
    text: text.trim(),
    hero: hero,
    heroName: heroName,
    mood: mood,
    setting: setting,
    ideasShown: ideasShown,
    config: config,
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
    Map<String, dynamic>? config,
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
      config: config,
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
    'config': ?config,
  };
}

/// A saved story as the child's dashboard lists it: one the child wrote
/// (Advanced writer) or one Sprout wrote with them (Beginning writer).
class StoredStory {
  final String id;
  final String title;

  /// `'advanced'` or `'beginning'`.
  final String writerLevel;
  final bool completed;

  /// The whole story as one text (guided parts or AI pages joined).
  final String text;

  // Advanced writer.
  final String mode;
  final String beginning, middle, end;
  final int ideasShown;

  // Beginning writer: the AI story's pages, what the child can pick next,
  // its quiz, and where they were.
  final List<String> pages;
  final List<String> choices;
  final List<Map<String, dynamic>> questions;
  final int page;
  final int chapters;

  final StoryConfig config;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  const StoredStory({
    required this.id,
    required this.title,
    required this.writerLevel,
    required this.completed,
    required this.text,
    required this.config,
    this.mode = 'free',
    this.beginning = '',
    this.middle = '',
    this.end = '',
    this.ideasShown = 0,
    this.pages = const [],
    this.choices = const [],
    this.questions = const [],
    this.page = 0,
    this.chapters = 1,
    this.updatedAt,
    this.completedAt,
  });

  bool get byAi => writerLevel == 'beginning';

  factory StoredStory.fromMap(String id, Map<String, dynamic> map) {
    DateTime? time(Object? value) => value is Timestamp ? value.toDate() : null;
    List<String> strings(Object? value) => [
      for (final v in (value as List?) ?? const []) v.toString(),
    ];
    final configMap = map['config'] as Map<String, dynamic>?;
    return StoredStory(
      id: id,
      title: map['title'] as String? ?? StoryDraft.defaultTitle,
      writerLevel: map['writerLevel'] as String? ?? 'advanced',
      completed: map['completedAt'] != null,
      text: map['text'] as String? ?? '',
      mode: map['mode'] as String? ?? 'free',
      beginning: map['beginning'] as String? ?? '',
      middle: map['middle'] as String? ?? '',
      end: map['end'] as String? ?? '',
      ideasShown: (map['ideasShown'] as num?)?.toInt() ?? 0,
      pages: strings(map['pages']),
      choices: strings(map['choices']),
      questions: [
        for (final q in (map['questions'] as List?) ?? const [])
          if (q is Map) Map<String, dynamic>.from(q),
      ],
      page: (map['page'] as num?)?.toInt() ?? 0,
      chapters: (map['chapters'] as num?)?.toInt() ?? 1,
      // Stories saved before the whole config was kept still have their
      // hero and picks.
      config: configMap != null
          ? storyConfigFromMap(configMap)
          : StoryConfig(
              hero: HeroConfig(
                character: map['hero'] as String?,
                name: map['heroName'] as String?,
              ),
              mood: map['mood'] as String?,
              setting: map['setting'] as String?,
            ),
      updatedAt: time(map['updatedAt']),
      completedAt: time(map['completedAt']),
    );
  }
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
      _write(childId, draft.toMap(), id: id, completed: false);

  /// Saves a story Sprout is writing with the child (Beginning writer):
  /// [fields] are its title, pages, choices, quiz and place. Creates it, or
  /// updates [id]. Returns the id.
  Future<String> saveAiStory(
    String childId,
    Map<String, dynamic> fields, {
    String? id,
    required bool completed,
  }) => _write(
    childId,
    {...fields, 'writerLevel': 'beginning', 'mode': 'ai'},
    id: id,
    completed: completed,
  );

  /// The child's stories, finished or not, most recently changed first.
  /// Empty when signed out.
  Future<List<StoredStory>> loadStories(String childId) async {
    final CollectionReference<Map<String, dynamic>> stories;
    try {
      stories = _stories(childId);
    } on StateError {
      return const [];
    }
    final snapshot = await stories.get();
    final list = [
      for (final doc in snapshot.docs) StoredStory.fromMap(doc.id, doc.data()),
    ];
    final never = DateTime.fromMillisecondsSinceEpoch(0);
    list.sort((a, b) => (b.updatedAt ?? never).compareTo(a.updatedAt ?? never));
    return list;
  }

  /// Fires when a story is saved, on this device or another. Empty when
  /// Firebase can't be reached, so a screen listing it with other services'
  /// streams keeps those.
  Stream<void> changes(String childId) {
    try {
      return changesOf(_stories(childId).snapshots());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Saves the story as finished (sets `completedAt`).
  Future<SavedStory> complete(
    String childId,
    StoryDraft draft, {
    String? id,
  }) async {
    final savedId = await _write(
      childId,
      draft.toMap(),
      id: id,
      completed: true,
    );
    return SavedStory(
      id: savedId,
      title: draft.effectiveTitle,
      text: draft.text,
    );
  }

  Future<String> _write(
    String childId,
    Map<String, dynamic> fields, {
    String? id,
    required bool completed,
  }) async {
    final stories = _stories(childId);
    final doc = id == null ? stories.doc() : stories.doc(id);
    final now = FieldValue.serverTimestamp();
    await doc.set({
      ...fields,
      // Only on the first write: merge would otherwise move it forward.
      if (id == null) 'createdAt': now,
      'updatedAt': now,
      // A finished story stays finished: a later save (the reader closing,
      // say) leaves completedAt alone rather than clearing it.
      if (completed)
        'completedAt': now
      else if (id == null)
        'completedAt': null,
    }, SetOptions(merge: true));
    return doc.id;
  }
}
