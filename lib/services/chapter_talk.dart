// "Talk about it": questions a parent can ask about the chapter their child
// just finished.
//
// The child's device writes them at the end of each chapter, from the
// chapter's own text (it has the book; the parent's device may not), and
// saves them under the parent's account, so they show on any device the
// parent signs in on. One document per book chapter at
// `parents/{uid}/children/{childId}/chapterTalk/{docId}`:
//   {title, chapter, chapterTitle, finishedAt, status, summary?, questions}
// where status is 'writing', 'ready' or 'failed'.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_service.dart';
import 'firestore_changes.dart';
import 'story_generator.dart' show ChapterTalkPoints;

enum ChapterTalkStatus { writing, ready, failed }

class ChapterTalk {
  final String title;
  final int chapter;
  final String chapterTitle;
  final DateTime finishedAt;
  final ChapterTalkStatus status;

  /// What happens in the chapter, for the parent. Empty until written.
  final String summary;
  final List<String> questions;

  const ChapterTalk({
    required this.title,
    required this.chapter,
    required this.chapterTitle,
    required this.finishedAt,
    required this.status,
    this.summary = '',
    this.questions = const [],
  });

  factory ChapterTalk.fromJson(Map<String, dynamic> json) => ChapterTalk(
    title: json['title'] as String? ?? '',
    chapter: (json['chapter'] as num?)?.toInt() ?? 0,
    chapterTitle: json['chapterTitle'] as String? ?? '',
    finishedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['finishedAt'] as num?)?.toInt() ?? 0,
    ),
    status: ChapterTalkStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => ChapterTalkStatus.failed,
    ),
    summary: json['summary'] as String? ?? '',
    questions: [...?(json['questions'] as List?)?.whereType<String>()],
  );
}

class ChapterTalkService {
  ChapterTalkService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance. Assignable only so tests can use in-memory fakes.
  static ChapterTalkService instance = ChapterTalkService();

  // Resolved lazily, like ActivityService: Firebase isn't set up in tests.
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
        .collection('chapterTalk');
  }

  /// One document per book chapter, so reading a chapter again updates it.
  static String docId(String title, int chapter) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 80 ? slug.substring(0, 80) : slug;
    return '${short.isEmpty ? 'book' : short}_$chapter';
  }

  /// Records that [childId] finished [chapter] of [title] and, unless that
  /// chapter already has them, has [write] come up with questions for the
  /// parent. Never throws: it runs in the background while the child reads.
  Future<void> chapterFinished(
    String childId, {
    required String title,
    required int chapter,
    required String chapterTitle,
    required Future<ChapterTalkPoints> Function() write,
  }) async {
    try {
      await ActivityService.instance.logEvent(childId, 'chapter_finished', {
        'title': title,
        'chapter': chapter,
        'chapterTitle': chapterTitle,
      });
    } catch (_) {}
    try {
      final collection = _collectionFor(childId);
      if (collection == null) return;
      final doc = collection.doc(docId(title, chapter));
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = (await doc.get()).data();
      if (existing != null &&
          existing['status'] == ChapterTalkStatus.ready.name) {
        await doc.update({'finishedAt': now});
        return;
      }
      await doc.set({
        'title': title,
        'chapter': chapter,
        'chapterTitle': chapterTitle,
        'finishedAt': now,
        'status': ChapterTalkStatus.writing.name,
        'questions': <String>[],
      });
      try {
        final points = await write();
        await doc.update({
          'summary': points.summary,
          'questions': points.questions,
          'status': ChapterTalkStatus.ready.name,
        });
      } catch (_) {
        await doc.update({'status': ChapterTalkStatus.failed.name});
      }
    } catch (_) {}
  }

  /// Every chapter [childId] has finished, most recent first. Empty when
  /// signed out.
  Future<List<ChapterTalk>> forChild(String childId) async {
    final collection = _collectionFor(childId);
    if (collection == null) return [];
    final snapshot = await collection.get();
    return [for (final doc in snapshot.docs) ChapterTalk.fromJson(doc.data())]
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  }

  /// Fires when a chapter is finished or its questions arrive.
  Stream<void> changes(String childId) {
    final collection = _collectionFor(childId);
    if (collection == null) return const Stream.empty();
    return changesOf(collection.snapshots());
  }
}
