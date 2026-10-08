import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/services/story_generator.dart';

const _config = StoryConfig(
  hero: HeroConfig(character: 'pal'),
  mood: 'Funny',
  setting: 'Forest',
);

Widget _screen(
  Future<Story> Function(StoryConfig, {Story? soFar, String? choice}) g,
) => MaterialApp(
  home: StoryReaderScreen(config: _config, childName: 'Mia', generate: g),
);

void main() {
  testWidgets('safety stop shows grown-up panel, no retry', (tester) async {
    await tester.pumpWidget(
      _screen((_, {soFar, choice}) async => throw const SafetyStopException()),
    );
    await tester.pumpAndSettle();
    expect(find.text("Let's talk to a grown-up about that"), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  test('hasBadWords catches swearing and slurs but not kid words', () {
    for (final s in ['a fox says shit', 'F*CK', 'sh1t happens', 'bitches',
        'a racist nigga joke', 'Kill your self', 'kys', 'KILL YOURSELF',
        'go die', 'i will kill you', 'k1ll urself', 'f u c k', 'f.u.c.k',
        's-h-i-t', 'fuuuuck', 'sh!t', 'phuck', 'youfuckingidiot',
        'k i l l y o u r s e l f', 'killurself', 'frick', 'kms']) {
      expect(hasBadWords(s), isTrue, reason: s);
    }
    for (final s in ['a cockatoo in a prickly bush', 'hello class',
        'Dickens wrote books', 'a scary assassin? no, a pass', 'raccoon', 'the dragon will die',
        'a big glass of milk', 'a phone call', 'I am 7 years old',
        'a fox, a cat, and a dog', 'the shiny sheep', 'Scotland']) {
      expect(hasBadWords(s), isFalse, reason: s);
    }
  });
}
