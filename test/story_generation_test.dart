import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/ai_story_screen.dart';
import 'package:storysprout/screens/story_character_screen.dart';
import 'package:storysprout/services/story_generator.dart';

/// Records the choices and defers to a scripted response.
class _FakeGenerator implements StoryGenerator {
  _FakeGenerator(this._respond);

  final Future<String> Function() _respond;
  final List<List<String>> calls = [];

  @override
  Future<String> generateStory({
    required String character,
    required String mood,
    required String setting,
  }) {
    calls.add([character, mood, setting]);
    return _respond();
  }
}

const _config = StoryConfig(
  character: 'Clever Fox',
  mood: 'Funny',
  setting: 'Forest',
);

Widget _app(StoryReaderScreen screen) => MaterialApp(home: screen);

void main() {
  testWidgets('sends the chosen character, mood, and setting to the generator',
      (tester) async {
    final generator =
        _FakeGenerator(() async => 'Once upon a time in the Forest...');
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    await tester.pumpAndSettle();

    expect(generator.calls.single, ['Clever Fox', 'Funny', 'Forest']);
    expect(find.text('Once upon a time in the Forest...'), findsOneWidget);
  });

  testWidgets('shows a loading message until the story arrives', (tester) async {
    final completer = Completer<String>();
    final generator = _FakeGenerator(() => completer.future);
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sprout is writing your story…'), findsOneWidget);

    completer.complete('The end.');
    await tester.pumpAndSettle();

    expect(find.text('The end.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(generator.calls, hasLength(1));
  });

  testWidgets('rebuilding does not generate the story again', (tester) async {
    final generator = _FakeGenerator(() async => 'One story.');
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    await tester.pumpAndSettle();

    expect(generator.calls, hasLength(1));
  });

  testWidgets('retry regenerates after a failure', (tester) async {
    var fail = true;
    final generator = _FakeGenerator(() async {
      if (fail) throw const StoryGenerationException('Blocked.');
      return 'Second try story.';
    });
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blocked.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Second try story.'), findsOneWidget);
    expect(generator.calls, hasLength(2));
  });

  testWidgets('a blank response shows retry UI instead of an empty story',
      (tester) async {
    final generator = _FakeGenerator(() async => '   \n ');
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    expect(find.textContaining('empty'), findsOneWidget);
  });

  testWidgets('leaving during generation does not throw', (tester) async {
    final completer = Completer<String>();
    final generator = _FakeGenerator(() => completer.future);
    await tester.pumpWidget(
      _app(StoryReaderScreen(config: _config, generator: generator)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    completer.completeError(const StoryGenerationException('Too late.'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  test('the prompt carries all three story choices', () {
    final prompt = StoryGenerator.storyPrompt(
      character: 'Clever Fox',
      mood: 'Funny',
      setting: 'Forest',
    );
    expect(prompt, contains('Clever Fox'));
    expect(prompt, contains('Funny'));
    expect(prompt, contains('Forest'));
  });
}
