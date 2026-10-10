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
    // Each report says which entries the chapter covers, nested sections
    // included, so the quiz can be written from them.
    expect(trigger.moveTo(4, pageTurn: true), (
      title: 'Chapter 1: A Hero is Unleashed',
      number: 1,
      entry: 2,
      end: 4,
    ));
    expect(trigger.moveTo(5, pageTurn: true), (
      title: 'CHAPTER II. The Pool of Tears',
      number: 2,
      entry: 4,
      end: 5,
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
      entry: 0,
      end: 1,
    ));
  });

  // Treasure Island's contents are flat: part title pages sit between
  // chapters titled by Roman numeral. The parts used to be taken for the
  // chapters, so a quiz came after a part's title page and never after a
  // chapter.
  test('chapters led by a Roman numeral, not the parts between them', () {
    final trigger = ChapterQuizTrigger([
      (title: 'TREASURE ISLAND', depth: 0), // 0
      (title: 'Illustrated by Louis Rhead', depth: 0), // 1
      (title: 'PART ONE—The Old Buccaneer', depth: 0), // 2
      (title: 'I The Old Sea-dog at the “Admiral Benbow”', depth: 0), // 3
      (title: 'II Black Dog Appears and Disappears', depth: 0), // 4
      (title: 'VI The Captain’s Papers', depth: 0), // 5
      (title: 'PART TWO—The Sea-cook', depth: 0), // 6
      (title: 'VII I Go to Bristol', depth: 0), // 7
    ]);
    trigger.moveTo(1, pageTurn: false);

    expect(trigger.moveTo(2, pageTurn: true), isNull); // into PART ONE
    expect(trigger.moveTo(3, pageTurn: true), isNull); // PART ONE -> I
    expect(trigger.moveTo(4, pageTurn: true)?.title, startsWith('I The Old'));
    expect(trigger.moveTo(5, pageTurn: true)?.number, 2); // II
    // VI ends at the PART TWO page, which isn't part of its text.
    final six = trigger.moveTo(6, pageTurn: true);
    expect((six?.number, six?.entry, six?.end), (3, 5, 6));
    expect(trigger.moveTo(7, pageTurn: true), isNull); // PART TWO -> VII
  });

  test('a part page that goes by unreported still ends the chapter', () {
    // On the phone the PART TWO page shares a file with a chapter, so the
    // reader goes from VI straight to VII.
    final trigger = ChapterQuizTrigger([
      (title: 'VI The Captain’s Papers', depth: 0), // 0
      (title: 'PART TWO—The Sea-cook', depth: 0), // 1
      (title: 'VII I Go to Bristol', depth: 0), // 2
      (title: 'VIII At the Sign of the Spy-glass', depth: 0), // 3
      (title: 'IX Powder and Arms', depth: 0), // 4
    ]);
    trigger.moveTo(0, pageTurn: false);

    final six = trigger.moveTo(2, pageTurn: true);
    expect(
      (six?.title, six?.entry, six?.end),
      ('VI The Captain’s Papers', 0, 1),
    );
    // Skipping a whole chapter (VII to IX) is still a jump, not reading on.
    expect(trigger.moveTo(4, pageTurn: true), isNull);
  });

  test('numbered chapters, and words that only look like numerals', () {
    final trigger = ChapterQuizTrigger([
      (title: 'Civil War', depth: 0), // not "C" "IVIL"
      (title: 'Illustrations', depth: 0),
      (title: '1. The Start', depth: 0),
      (title: '2 The Middle', depth: 0),
      (title: 'Index', depth: 0),
    ]);
    trigger.moveTo(0, pageTurn: false);

    expect(trigger.moveTo(1, pageTurn: true), isNull);
    expect(trigger.moveTo(2, pageTurn: true), isNull);
    expect(trigger.moveTo(3, pageTurn: true)?.number, 1);
    expect(trigger.moveTo(4, pageTurn: true)?.number, 2);
  });

  test('parts are quizzed when the chapters are not titled as such', () {
    final trigger = ChapterQuizTrigger([
      (title: 'Contents', depth: 0),
      (title: 'Part One', depth: 0),
      (title: 'Part Two', depth: 0),
    ]);
    trigger.moveTo(1, pageTurn: false);

    expect(trigger.moveTo(2, pageTurn: true)?.title, 'Part One');
  });

  test('positions before the first entry are ignored', () {
    final trigger = ChapterQuizTrigger(contents);

    expect(trigger.moveTo(null, pageTurn: false), isNull);
    expect(trigger.moveTo(2, pageTurn: true), isNull);
  });
}
