import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/story/hero_config.dart';
import 'package:storysprout/screens/story/story_config.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/screens/story_summary_screen.dart';
import 'package:storysprout/services/story_generator.dart';

const _config = StoryConfig(
  hero: HeroConfig(character: 'pal', name: 'Clever Fox'),
  mood: 'Funny',
  setting: 'Forest',
);

Map<String, dynamic> _json() => {
  'title': 'Fox Finds a Hat',
  'pages': [
    {'pageNumber': 1, 'text': 'Fox saw a hat.'},
    {'pageNumber': 2, 'text': '   '},
    {'pageNumber': 3, 'text': 'Fox wore the hat.'},
  ],
  'questions': [
    {
      'question': 'What did Fox find?',
      'answers': ['A hat', 'A shoe', 'A cake'],
      'correct': 0,
    },
    {
      'question': 'Bad index',
      'answers': ['a', 'b'],
      'correct': 5,
    },
    {'question': 'Missing answers', 'correct': 0},
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // flutter_tts has no platform side in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });

  group('Story.fromJson', () {
    test('keeps non-empty pages and only valid questions', () {
      final story = Story.fromJson(_json());
      expect(story.title, 'Fox Finds a Hat');
      expect(story.pages, ['Fox saw a hat.', 'Fox wore the hat.']);
      expect(story.questions.map((q) => q.question), ['What did Fox find?']);
    });

    test('reads up to 3 choices; a story with none has ended', () {
      final story = Story.fromJson({
        ..._json(),
        'choices': ['Climb the tree', ' ', 'Ask Owl', 'Nap', 'Dance'],
      });
      expect(story.choices, ['Climb the tree', 'Ask Owl', 'Nap']);
      expect(story.ended, isFalse);
      expect(Story.fromJson(_json()).ended, isTrue);
    });

    test('strips JSON punctuation a model leaked into a page', () {
      final story = Story.fromJson({
        'title': 'x',
        'pages': [
          {'text': "'Hi,' said Fox. Oops.'},{"},
          {'text': 'He said "Wow!"}]'},
          {'text': '},{'},
          {'text': 'Plain page.'},
        ],
      });
      expect(story.pages, [
        "'Hi,' said Fox. Oops.",
        'He said "Wow!"',
        'Plain page.',
      ]);
    });

    test('rejects a story without pages', () {
      expect(
        () => Story.fromJson({'title': 'x', 'pages': []}),
        throwsFormatException,
      );
      expect(
        () => Story.fromJson({
          'pages': [
            {'text': 'hi'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  testWidgets('story idea is trimmed, retained on back, and can be cleared', (
    tester,
  ) async {
    StoryConfig? submitted;
    String? kept;
    await tester.pumpWidget(
      MaterialApp(
        home: StorySummaryScreen(
          config: _config,
          onIdeaChanged: (idea) => kept = idea,
          onStartReading: (config) => submitted = config,
        ),
      ),
    );
    Future<void> writeIdea(String chip, String text) async {
      await tester.tap(find.text(chip));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      await tester.tap(find.text('Use this idea'));
      await tester.pumpAndSettle();
    }

    await writeIdea('Add an idea', '  Fox builds a treehouse.  ');
    await tester.ensureVisible(find.text('Start Reading!'));
    await tester.tap(find.text('Start Reading!'));
    expect(submitted!.idea, 'Fox builds a treehouse.');
    expect(submitted!.hero.name, _config.hero.name);
    expect(submitted!.mood, _config.mood);
    expect(submitted!.setting, _config.setting);
    // What the flow keeps for when the child comes back to this step.
    expect(kept, submitted!.idea);

    await writeIdea('Edit idea', '   ');
    await tester.ensureVisible(find.text('Start Reading!'));
    await tester.tap(find.text('Start Reading!'));
    expect(submitted!.idea, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test(
    'generation rejects oversized story ideas before contacting AI',
    () async {
      await expectLater(
        generateStory(_config.copyWith(idea: 'x' * 501)),
        throwsArgumentError,
      );
    },
  );

  group('safety', () {
    test('redactPII leaves ordinary story text alone', () {
      const text = '3 little pigs walked down the road.\n\n'
          '5 friends met Dr Owl and went to school.';
      expect(redactPII(text), text);
      expect(redactPII('I go to Lincoln Elementary'), 'I go to [removed]');
    });

    test('needsGrownUp catches common variants', () {
      for (final s in ['he hit me', 'I was abused', 'kill my self',
          "I don't want to live"]) {
        expect(needsGrownUp(s), isTrue, reason: s);
      }
    });

    test('redactPII removes phone, email and address', () {
      final redacted = redactPII(
        'Call 555-867-5309 or email fox@example.com, '
        'he lives at 12 Oak Street and goes to 5 Elm Elementary.',
      );
      expect(redacted, isNot(contains('555-867-5309')));
      expect(redacted, isNot(contains('fox@example.com')));
      expect(redacted, isNot(contains('12 Oak Street')));
      expect(redacted, isNot(contains('5 Elm Elementary')));
      expect(redacted, contains('[removed]'));
    });

    test('needsGrownUp flags self-harm but not a dragon that will die', () {
      expect(needsGrownUp('a brave dragon story'), isFalse);
      expect(needsGrownUp('the dragon will die'), isFalse);
      expect(needsGrownUp('I want to die'), isTrue);
      expect(needsGrownUp('my dad hits me'), isTrue);
    });

    test('unsafe idea throws SafetyStopException without a backend', () async {
      await expectLater(
        generateStory(_config.copyWith(idea: 'I want to die')),
        throwsA(isA<SafetyStopException>()),
      );
    });
  });

  test('isQuotaError recognises quota and rate-limit errors', () {
    expect(isQuotaError(Exception('You exceeded your current quota')), isTrue);
    expect(isQuotaError(Exception('Gemini 429: Too Many Requests')), isTrue);
    expect(isQuotaError(Exception('Local model 500: http://10.0.2.2:4290')), isFalse);
    expect(isQuotaError(Exception('RESOURCE_EXHAUSTED')), isTrue);
    expect(isQuotaError(Exception('network down')), isFalse);
  });

  testWidgets('generated story pages through to its quiz', (
    tester,
  ) async {
    final completer = Completer<Story>();
    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config: _config,
          childId: '1',
          childName: 'Mia',
          generate: (_, {soFar, choice}) => completer.future,
        ),
      ),
    );
    expect(find.text('Sprout is writing your story…'), findsOneWidget);

    completer.complete(Story.fromJson(_json()));
    await tester.pumpAndSettle();
    expect(find.text('Fox saw a hat.'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz time!'));
    await tester.pumpAndSettle();
    expect(find.text('What did Fox find?'), findsOneWidget);
  });

  testWidgets('generation failure shows the offline story', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config: _config,
          childName: 'Mia',
          generate: (_, {soFar, choice}) async => throw Exception('no network'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(
      find.text('Once upon a time, in Forest, there lived Clever Fox.'),
      findsOneWidget,
    );
  });

  testWidgets('quota failure shows the resting banner, not the cloud one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config: _config,
          childName: 'Mia',
          generate: (_, {soFar, choice}) async =>
              throw Exception('You exceeded your current quota'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Sprout is resting after lots of stories, so here's a classic! Try again in a minute.",
      ),
      findsOneWidget,
    );
    expect(
      find.text("Sprout couldn't reach the story cloud, so here's a classic!"),
      findsNothing,
    );
  });

  testWidgets('non-quota failure keeps the story-cloud banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config: _config,
          childName: 'Mia',
          generate: (_, {soFar, choice}) async => throw Exception('network down'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Sprout couldn't reach the story cloud, so here's a classic!"),
      findsOneWidget,
    );
  });

  testWidgets('child picks what happens next, then finishes the story', (
    tester,
  ) async {
    final calls = <String>[];
    Future<Story> fake(StoryConfig _, {Story? soFar, String? choice}) async {
      calls.add(soFar == null ? 'start' : choice ?? 'end');
      if (soFar == null) {
        return const Story(
          title: 'Fox and the Tree',
          pages: ['Fox found a tall tree.'],
          choices: ['Climb the tree', 'Ask Owl'],
        );
      }
      if (choice != null) {
        return Story(
          title: 'ignored',
          pages: ['Fox chose to ${choice.toLowerCase()}.'],
          choices: const ['Go home'],
        );
      }
      return Story.fromJson({
        ..._json(),
        'pages': [
          {'text': 'Fox went home happy.'},
        ],
      });
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StoryReaderScreen(
          config: _config,
          childId: '1',
          childName: 'Mia',
          generate: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What happens next?'), findsOneWidget);

    await tester.ensureVisible(find.text('Ask Owl'));
    await tester.tap(find.text('Ask Owl'));
    await tester.pumpAndSettle();
    expect(find.text('Fox chose to ask owl.'), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('Fox and the Tree'), findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    await tester.ensureVisible(find.text('I want to write what happens!'));
    await tester.tap(find.text('I want to write what happens!'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Fox makes a kite  ');
    await tester.tap(find.byTooltip('Use my idea'));
    await tester.pumpAndSettle();
    expect(find.text('Fox chose to fox makes a kite.'), findsOneWidget);
    expect(find.text('Page 3 of 3'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.ensureVisible(find.text('Finish the story'));
    await tester.tap(find.text('Finish the story'));
    await tester.pumpAndSettle();
    expect(find.text('Fox went home happy.'), findsOneWidget);
    expect(find.text('What happens next?'), findsNothing);
    expect(calls, ['start', 'Ask Owl', 'Fox makes a kite', 'end']);

    await tester.tap(find.text('Quiz time!'));
    await tester.pumpAndSettle();
    expect(find.text('What did Fox find?'), findsOneWidget);
  });

  testWidgets('finishing a story returns to the dashboard, not the wizard', (
    tester,
  ) async {
    // Phone-sized, so every step fits (see story_no_scroll_test).
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StoryFlowScreen(childName: 'Mia'),
              ),
            ),
            child: const Text('Dashboard'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    Future<void> tapVisible(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapVisible('Next');
    await tapVisible('Forest');
    await tapVisible('Next');
    await tapVisible('Funny');
    await tapVisible('Next');
    await tapVisible('Add an idea');
    await tester.enterText(find.byType(TextField).last, 'Fox builds a treehouse.');
    await tapVisible('Use this idea');
    // Back a step and forward again keeps what they typed.
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tapVisible('Next');
    await tapVisible('Edit idea');
    expect(find.text('Fox builds a treehouse.'), findsOneWidget);
    await tapVisible('Use this idea');
    // No Firebase in tests, so generation fails and the offline story shows.
    await tapVisible('Start Reading!');
    expect(find.text('Try again'), findsOneWidget);
    while (find.text('The End').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('The End'));
    await tester.pumpAndSettle();
    await tapVisible('Return Home');
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Start Reading!'), findsNothing);
  });

  test('bookExcerpt strips markup and Gutenberg boilerplate, keeps budget', () {
    final html = [
      '<html><head><title>x</title><style>p{}</style></head><body>'
          '<p>*** START OF THE PROJECT GUTENBERG EBOOK ALICE ***</p></body></html>',
      '<p>Alice &amp; the <b>Rabbit</b></p>',
      '<p>${'story ' * 5000}</p>',
      '<p>*** END OF THE PROJECT GUTENBERG EBOOK ***</p><p>LICENSE</p>',
    ];
    final excerpt = bookExcerpt(html, budget: 800);
    expect(excerpt, startsWith('Alice &amp; the Rabbit'));
    expect(excerpt, isNot(contains('<')));
    expect(excerpt, isNot(contains('START OF')));
    expect(excerpt, isNot(contains('LICENSE')));
    expect(excerpt.replaceAll('\n…\n', '').length, 800);
    expect(bookExcerpt(html.sublist(1, 2)), 'Alice &amp; the Rabbit');
  });
}
