import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/question_bank.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const alice = "Alice's Adventures in Wonderland";

  test('every Alice chapter has three well-formed questions', () async {
    final bank = QuestionBank();
    for (var chapter = 1; chapter <= 12; chapter++) {
      final questions = await bank.chapterQuestions(
        bookTitle: alice,
        chapter: chapter,
      );
      expect(questions, hasLength(3), reason: 'chapter $chapter');
      for (final q in questions!) {
        expect(q.question, isNotEmpty);
        expect(q.answers, hasLength(3), reason: q.question);
        expect(q.correctIndex, inInclusiveRange(0, 2), reason: q.question);
      }
    }
    expect(await bank.chapterQuestions(bookTitle: alice, chapter: 13), isNull);
  });

  test('the right answer is not always in the same place', () async {
    final bank = QuestionBank();
    final positions = <int>{};
    for (var chapter = 1; chapter <= 12; chapter++) {
      final questions = await bank.chapterQuestions(
        bookTitle: alice,
        chapter: chapter,
      );
      positions.addAll(questions!.map((q) => q.correctIndex));
    }
    expect(positions, {0, 1, 2});
  });

  test('books match on title regardless of case and apostrophes', () async {
    final bank = QuestionBank();

    final curly = await bank.chapterQuestions(
      bookTitle: 'ALICE’S ADVENTURES IN WONDERLAND',
      chapter: 1,
    );
    expect(curly?.first.question, contains('White Rabbit'));
    expect(
      await bank.chapterQuestions(bookTitle: 'Dog Man', chapter: 1),
      isNull,
    );
    expect(await bank.chapterQuestions(bookTitle: null, chapter: 1), isNull);
  });

  testWidgets('the quiz shows the questions it is given', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    final questions = await tester.runAsync(
      () => QuestionBank().chapterQuestions(bookTitle: alice, chapter: 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComprehensionScreen(
          childId: '1',
          childName: 'Alex',
          bookTitle: alice,
          chapterNumber: 8,
          chapterTitle: "CHAPTER VIII. The Queen's Croquet-Ground",
          skippable: true,
          questions: questions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('What were the gardeners doing to the white rose tree?'),
      findsOneWidget,
    );
    expect(find.text('Painting the roses red'), findsOneWidget);
    expect(find.text('What did the little seed need to grow?'), findsNothing);
  });
}
