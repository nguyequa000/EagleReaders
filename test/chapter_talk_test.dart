import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/chapter_talk.dart';
import 'package:storysprout/services/story_generator.dart';

import 'test_helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ChapterTalkService talk;

  setUp(() {
    final fb = signedIn();
    firestore = fb.firestore;
    ActivityService.instance = fb.activity;
    talk = ChapterTalkService(firestore: fb.firestore, auth: fb.auth);
  });

  const points = (
    summary: 'Alice follows a white rabbit down a hole.',
    questions: ['Why did Alice follow the rabbit?', 'How would you feel?'],
  );

  Future<void> finish(
    int chapter, {
    String title = 'Alice',
    Future<ChapterTalkPoints> Function()? write,
  }) => talk.chapterFinished(
    '1',
    title: title,
    chapter: chapter,
    chapterTitle: 'Chapter $chapter',
    write: write ?? () async => points,
  );

  test('a finished chapter is logged and gets questions', () async {
    await finish(1);

    final events = await activityDocs(firestore, '1');
    expect(events.single['type'], 'chapter_finished');
    expect(events.single['chapter'], 1);
    final talks = await talk.forChild('1');
    expect(talks.single.status, ChapterTalkStatus.ready);
    expect(talks.single.summary, points.summary);
    expect(talks.single.questions, points.questions);
    expect(
      ActivityEvent.fromJson(events.single).describe('Mika'),
      'Mika finished Chapter 1 of "Alice"',
    );
  });

  test('reading a chapter again keeps its questions', () async {
    await finish(1);
    var calls = 0;
    await finish(
      1,
      write: () async {
        calls++;
        return points;
      },
    );
    expect(calls, 0);
    expect(await talk.forChild('1'), hasLength(1));
    expect(await activityDocs(firestore, '1'), hasLength(2));
  });

  test('a failed write is marked, and tried again next time', () async {
    await finish(2, write: () => Future.error(StateError('offline')));
    expect((await talk.forChild('1')).single.status, ChapterTalkStatus.failed);

    await finish(2);
    expect((await talk.forChild('1')).single.status, ChapterTalkStatus.ready);
  });

  test('the latest chapter comes first', () async {
    await finish(1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await finish(2);
    expect([for (final t in await talk.forChild('1')) t.chapter], [2, 1]);
  });

  test('signed out, nothing is written or thrown', () async {
    final out = ChapterTalkService(
      firestore: firestore,
      auth: MockFirebaseAuth(),
    );
    await out.chapterFinished(
      '1',
      title: 'Alice',
      chapter: 1,
      chapterTitle: 'One',
      write: () async => points,
    );
    expect(await out.forChild('1'), isEmpty);
  });

  test('doc ids are stable and safe', () {
    expect(
      ChapterTalkService.docId("Alice's Adventures in Wonderland", 3),
      'alice-s-adventures-in-wonderland_3',
    );
    expect(ChapterTalkService.docId('???', 1), 'book_1');
  });

  group('parseChapterTalk', () {
    test('keeps the summary and the non-empty questions', () {
      final parsed = parseChapterTalk(
        '{"summary": " A rabbit. ", "questions": [" Why? ", "", "What next?"]}',
      );
      expect(parsed.summary, 'A rabbit.');
      expect(parsed.questions, ['Why?', 'What next?']);
    });

    test('no questions is an error', () {
      expect(
        () => parseChapterTalk('{"summary": "x", "questions": []}'),
        throwsFormatException,
      );
    });
  });
}
