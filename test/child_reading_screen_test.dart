import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/child_reading_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/chapter_talk.dart';
import 'package:storysprout/services/story_generator.dart';

import 'test_helpers.dart';

void main() {
  late ActivityService activity;
  late ChapterTalkService talk;

  setUp(() {
    final fb = signedIn();
    activity = fb.activity;
    ActivityService.instance = activity;
    talk = ChapterTalkService.instance = ChapterTalkService(
      firestore: fb.firestore,
      auth: fb.auth,
    );
  });
  tearDown(() => ChapterTalkService.instance = ChapterTalkService());

  Future<void> finish(
    int chapter,
    String chapterTitle, {
    Future<ChapterTalkPoints> Function()? write,
  }) => talk.chapterFinished(
    '1',
    title: 'Alice',
    chapter: chapter,
    chapterTitle: chapterTitle,
    write:
        write ??
        () async => (
          summary: 'Summary of $chapterTitle.',
          questions: ['Question about $chapterTitle?'],
        ),
  );

  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChildReadingScreen(
          childId: '1',
          childName: 'Mika',
          bookTitle: 'Alice',
        ),
      ),
    );
    // The "writing" spinner never settles.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('shows progress, the summary and questions to ask', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await activity.logEvent('1', 'reading_session', {
        'title': 'Alice',
        'minutes': 12,
        'bookType': 'epub',
      });
      await finish(1, 'Down the Rabbit-Hole');
      await activity.logEvent('1', 'comprehension_result', {
        'title': 'Alice',
        'chapter': 1,
        'correct': 2,
        'total': 3,
      });
    });
    await open(tester);

    expect(
      find.text('Finished Chapter 1: Down the Rabbit-Hole · just now'),
      findsOneWidget,
    );
    expect(find.text('1 chapter finished · 12 min read'), findsOneWidget);
    expect(find.text('Chapter quiz: 2 of 3 right'), findsOneWidget);
    expect(find.text('Summary of Down the Rabbit-Hole.'), findsOneWidget);
    expect(find.text('Questions to ask Mika'), findsOneWidget);
    expect(
      find.textContaining('Mika just finished Chapter 1: Down the'),
      findsOneWidget,
    );
    expect(find.text('Question about Down the Rabbit-Hole?'), findsOneWidget);
  });

  testWidgets('a chapter title that says which chapter it is stays as is', (
    tester,
  ) async {
    await tester.runAsync(() => finish(1, 'CHAPTER I. Down the Rabbit-Hole'));
    await open(tester);
    expect(
      find.text('Finished CHAPTER I. Down the Rabbit-Hole · just now'),
      findsOneWidget,
    );
  });

  testWidgets('earlier chapters open to their own questions', (tester) async {
    await tester.runAsync(() async {
      await finish(1, 'One');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await finish(2, 'Two');
    });
    await open(tester);

    expect(find.text('Question about Two?'), findsOneWidget);
    expect(find.text('Question about One?'), findsNothing);
    await tester.scrollUntilVisible(find.text('Chapter 1: One'), 200);
    await tester.tap(find.text('Chapter 1: One'));
    await tester.pumpAndSettle();
    expect(find.text('Question about One?'), findsOneWidget);
  });

  testWidgets('questions still being written, then arriving', (tester) async {
    final pending = Completer<ChapterTalkPoints>();
    unawaited(finish(1, 'One', write: () => pending.future));
    await tester.pump();
    await open(tester, settle: false);
    expect(find.text('Sprout is writing questions…'), findsOneWidget);

    pending.complete((summary: 'Done.', questions: ['Ready now?']));
    await tester.pump();
    // The live refresh waits a moment to batch writes together.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Ready now?'), findsOneWidget);
  });

  testWidgets('a failed chapter says so', (tester) async {
    await tester.runAsync(
      () => finish(1, 'One', write: () => Future.error(StateError('x'))),
    );
    await open(tester);
    expect(
      find.text('No questions for this chapter this time.'),
      findsOneWidget,
    );
  });

  testWidgets('nothing finished yet explains what will appear', (tester) async {
    await open(tester);
    expect(
      find.text(
        'When Mika finishes a chapter, questions to ask will show up here.',
      ),
      findsOneWidget,
    );
  });
}
