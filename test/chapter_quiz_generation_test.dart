// End-of-chapter quizzes are written by Gemini from the chapter itself: its
// text, or for picture books a few of its pages.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/paged_text_view.dart';
import 'package:storysprout/services/book_library.dart';
import 'package:storysprout/services/story_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('short picture chapters send every page', () {
    expect(quizPages(1), [0]);
    expect(quizPages(4), [0, 1, 2, 3]);
    expect(quizPages(maxQuizPages), List.generate(maxQuizPages, (i) => i));
  });

  test('long picture chapters send evenly spaced pages, first to last', () {
    final picked = quizPages(30);
    expect(picked, hasLength(maxQuizPages));
    expect(picked.first, 0);
    expect(picked.last, 29);
    for (var i = 1; i < picked.length; i++) {
      expect(picked[i], greaterThan(picked[i - 1]));
    }
  });

  test('a chapter with no text is refused before asking Gemini', () {
    expect(
      () => generateChapterQuestions('Book', 'Chapter 1', [
        '<html><body><img src="a.png"/></body></html>',
      ]),
      throwsFormatException,
    );
  });

  test('the paged reader has each spine file\'s text for the quiz', () async {
    final book = await BookLibrary.readDocument(
      File('assets/books/alice_in_wonderland.epub').readAsBytesSync(),
    );
    final paged = PagedTextBook(
      const PagedTextSource.asset('assets/books/alice_in_wonderland.epub'),
      book,
    );

    expect(paged.spineHtml, hasLength(paged.spine.length));
    // Chapter I's own file: its heading and its story, not just the
    // contents page listing it.
    final chapterOne = paged.spineHtml.indexWhere(
      (html) => html.contains('White Rabbit'),
    );
    expect(chapterOne, isNonNegative);
    expect(
      bookExcerpt([paged.spineHtml[chapterOne]]),
      allOf(contains('Down the Rabbit-Hole'), contains('burning with curiosity')),
    );
  });
}
