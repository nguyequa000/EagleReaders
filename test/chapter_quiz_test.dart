import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/chapter_quiz.dart';

void main() {
  // Shaped like the contents of a real comic and a Gutenberg novel: front
  // matter, numbered chapters (one with a nested section), back matter.
  final contents = <QuizContentsEntry>[
    (title: 'Cover', depth: 0), // 0
    (title: 'Contents', depth: 0), // 1
    (title: 'Chapter 1: A Hero is Unleashed', depth: 0), // 2
    (title: 'Part A', depth: 1), // 3
    (title: 'CHAPTER II. The Pool of Tears', depth: 0), // 4
    (title: 'How to Draw', depth: 0), // 5
  ];

  test('turning the page out of a chapter quizzes that chapter', () {
    final trigger = ChapterQuizTrigger(contents);
    trigger.moveTo(2, pageTurn: false); // opened the book in Chapter 1

    expect(trigger.moveTo(2, pageTurn: true), isNull); // still in it
    expect(trigger.moveTo(4, pageTurn: true), (
      title: 'Chapter 1: A Hero is Unleashed',
      number: 1,
    ));
    expect(trigger.moveTo(5, pageTurn: true), (
      title: 'CHAPTER II. The Pool of Tears',
      number: 2,
    ));
  });

  test('a nested section belongs to its chapter', () {
    final trigger = ChapterQuizTrigger(contents);
    trigger.moveTo(2, pageTurn: false);

    expect(trigger.moveTo(3, pageTurn: true), isNull); // into Part A
    expect(trigger.moveTo(4, pageTurn: true)?.number, 1);
  });

  test('front and back matter get no quiz', () {
    final trigger = ChapterQuizTrigger(contents);
    trigger.moveTo(0, pageTurn: false);

    expect(trigger.moveTo(1, pageTurn: true), isNull); // Cover -> Contents
    expect(trigger.moveTo(2, pageTurn: true), isNull); // Contents -> Ch 1
  });

  test('jumps, going backwards and skipping ahead never quiz', () {
    final trigger = ChapterQuizTrigger(contents);
    trigger.moveTo(2, pageTurn: false);

    expect(trigger.moveTo(4, pageTurn: false), isNull); // Contents jump
    expect(trigger.moveTo(2, pageTurn: true), isNull); // back a page
    expect(trigger.moveTo(5, pageTurn: true), isNull); // not the next one
  });

  test('each chapter is quizzed once per session', () {
    final trigger = ChapterQuizTrigger(contents);
    trigger.moveTo(2, pageTurn: false);

    expect(trigger.moveTo(4, pageTurn: true), isNotNull);
    trigger.moveTo(2, pageTurn: true); // re-read the end of Chapter 1
    expect(trigger.moveTo(4, pageTurn: true), isNull);
  });

  test('without "Chapter" titles every top-level entry is a chapter', () {
    final trigger = ChapterQuizTrigger([
      (title: 'The Boy Who Lived', depth: 0),
      (title: 'The Vanishing Glass', depth: 0),
    ]);
    trigger.moveTo(0, pageTurn: false);

    expect(trigger.moveTo(1, pageTurn: true), (
      title: 'The Boy Who Lived',
      number: 1,
    ));
  });

  test('positions before the first entry are ignored', () {
    final trigger = ChapterQuizTrigger(contents);

    expect(trigger.moveTo(null, pageTurn: false), isNull);
    expect(trigger.moveTo(2, pageTurn: true), isNull);
  });
}
