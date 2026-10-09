import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/reader_audience.dart';
import 'package:storysprout/services/story_generator.dart';

void main() {
  tearDown(() => ReaderAudience.current = AgeBand.fallback);

  test('every placeholder in every prompt is filled for every band', () {
    for (final band in AgeBand.values) {
      for (final prompt in systemPromptsForTest) {
        final filled = forAudience(prompt, band);
        expect(filled, isNot(contains('{')), reason: '$band: $filled');
        expect(filled, contains(band.audience));
      }
    }
  });

  test('stories and quizzes follow the band', () {
    final story = systemPromptsForTest.first;
    final quizzes = systemPromptsForTest.skip(1);

    final young = forAudience(story, AgeBand.ages3to5);
    expect(young, contains('kids aged 3 to 5'));
    expect(young, contains('4-year-old'));
    expect(young, contains('1 or 2 sentences'));
    for (final quiz in quizzes) {
      expect(
        forAudience(quiz, AgeBand.ages9to10),
        contains(AgeBand.ages9to10.quizLevel),
      );
    }
  });

  test('the default keeps the reading level the prompts always had', () {
    final story = forAudience(systemPromptsForTest.first, AgeBand.fallback);
    expect(
      story,
      contains(
        'Use short sentences and simple, everyday words a 6-year-old can read.',
      ),
    );
    expect(story, contains('Each page is 2 to 4 sentences.'));
    expect(
      forAudience(systemPromptsForTest[1], AgeBand.fallback),
      contains('Use short, simple words a 6-year-old can read.'),
    );
  });

  test('stored names map back to bands, unknown ones to the default', () {
    for (final band in AgeBand.values) {
      expect(AgeBand.fromName(band.name), band);
    }
    expect(AgeBand.fromName(null), AgeBand.fallback);
    expect(AgeBand.fromName('ages99'), AgeBand.fallback);
  });

  test('only the youngest band hides Spooky', () {
    expect(AgeBand.ages3to5.allowsSpooky, isFalse);
    expect(AgeBand.ages6to8.allowsSpooky, isTrue);
    expect(AgeBand.ages9to10.allowsSpooky, isTrue);
  });

  test("each band's summary describes what the band really does", () {
    for (final band in AgeBand.values) {
      // The page length shown to parents is the one Gemini is told.
      final pages = RegExp(r'\d–\d').firstMatch(band.summary)!.group(0)!;
      expect(
        band.pageLength.replaceAll(' to ', '–').replaceAll(' or ', '–'),
        contains(pages),
        reason: band.label,
      );
      expect(
        band.summary.contains('Spooky stories are hidden'),
        !band.allowsSpooky,
        reason: band.label,
      );
    }
  });
}
