import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_option.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each catalog holds exactly four options', () {
    expect(StoryOptions.moods, hasLength(4));
    expect(StoryOptions.settings, hasLength(4));
  });

  test('labels match the strings the flow tests assert on', () {
    expect(
      StoryOptions.moods.map((o) => o.label),
      ['Funny', 'Adventurous', 'Spooky', 'Calm'],
    );
    expect(
      StoryOptions.settings.map((o) => o.label),
      ['Forest', 'Ocean', 'City', 'Outer Space'],
    );
  });

  test('every referenced asset actually resolves', () async {
    final all = [
      ...StoryOptions.moods,
      ...StoryOptions.settings,
    ];
    for (final option in all) {
      final data = await rootBundle.loadString(option.asset);
      expect(data, contains('<svg'), reason: '${option.label} -> ${option.asset}');
    }
  });

  test('byLabel finds a match and returns null otherwise', () {
    expect(
      StoryOptions.byLabel(StoryOptions.moods, 'Spooky')?.asset,
      'assets/story/moods/spooky.svg',
    );
    expect(StoryOptions.byLabel(StoryOptions.moods, 'Nonexistent'), isNull);
    expect(StoryOptions.byLabel(StoryOptions.moods, null), isNull);
  });
}
