import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/say_it_button.dart';
import 'package:storysprout/services/word_speaker.dart';

void main() {
  group('WordSpeaker.sayable', () {
    test('trims punctuation and quotes from the ends', () {
      expect(WordSpeaker.sayable('"Curiouser!"'), 'Curiouser');
      expect(WordSpeaker.sayable('  (rabbit-hole), '), 'rabbit-hole');
      expect(WordSpeaker.sayable('“Alice’s”'), 'Alice’s');
    });

    test("keeps apostrophes and hyphens inside a word", () {
      expect(WordSpeaker.sayable("don't,"), "don't");
      expect(WordSpeaker.sayable('well-known.'), 'well-known');
    });

    test('collapses spaces and line breaks', () {
      expect(WordSpeaker.sayable('down\n  the\thole'), 'down the hole');
    });

    test('no letters, nothing to say', () {
      expect(WordSpeaker.sayable('...'), isNull);
      expect(WordSpeaker.sayable('123'), isNull);
      expect(WordSpeaker.sayable('   '), isNull);
    });

    test('a long selection stops at a word near the limit', () {
      final long = List.filled(100, 'rabbit').join(' ');
      final said = WordSpeaker.sayable(long)!;
      expect(said.length, lessThanOrEqualTo(WordSpeaker.maxLength));
      expect(said, endsWith('rabbit'));
    });
  });

  group('WordSpeaker.say', () {
    test('speaks the cleaned-up word', () async {
      final spoken = <String>[];
      final speaker = WordSpeaker(speak: (t) async => spoken.add(t));
      await speaker.say('"Wonderland!"');
      await speaker.say('?!');
      expect(spoken, ['Wonderland']);
    });

    test('a failing speech engine is ignored', () async {
      final speaker = WordSpeaker(speak: (_) => Future.error(StateError('x')));
      await speaker.say('Alice');
    });
  });

  group('SayItButton.place', () {
    const view = Size(360, 600);
    const button = Size(120, 48);

    test('centred just above a word mid-page', () {
      const word = Rect.fromLTWH(150, 300, 60, 24);
      final at = SayItButton.place(word, view, button);
      expect(at.dx, word.center.dx - button.width / 2);
      expect(at.dy + button.height, lessThanOrEqualTo(word.top));
    });

    test('below a word on the top line', () {
      const word = Rect.fromLTWH(150, 10, 60, 24);
      final at = SayItButton.place(word, view, button);
      expect(at.dy, greaterThanOrEqualTo(word.bottom));
    });

    test('kept inside the page at either edge', () {
      final left = SayItButton.place(
        const Rect.fromLTWH(0, 300, 30, 24),
        view,
        button,
      );
      expect(left.dx, greaterThanOrEqualTo(0));
      final right = SayItButton.place(
        const Rect.fromLTWH(340, 300, 20, 24),
        view,
        button,
      );
      expect(right.dx + button.width, lessThanOrEqualTo(view.width));
    });
  });

  testWidgets('the button says "Say it" and taps through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SayItButton(onTap: () => taps++)),
        ),
      ),
    );
    expect(find.text('🔊 Say it'), findsOneWidget);
    expect(find.bySemanticsLabel('Say this word'), findsOneWidget);
    await tester.tap(find.byKey(const Key('say-it')));
    expect(taps, 1);
  });

  testWidgets('the popup sits above the word, inside the page', (tester) async {
    const word = Rect.fromLTWH(300, 300, 50, 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 600,
              child: SayItPopup(selection: word, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    final pill = tester.getRect(find.byKey(const Key('say-it')));
    expect(pill.bottom, lessThanOrEqualTo(word.top));
    expect(pill.right, lessThanOrEqualTo(360));
    expect(pill.left, greaterThanOrEqualTo(0));
    // Only the pill takes taps, not a strip down the page.
    expect(pill.height, lessThanOrEqualTo(60));
  });
}
