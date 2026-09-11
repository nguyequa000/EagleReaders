import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _expectedAssets = <String>[
  'assets/story/characters/knight.svg',
  'assets/story/characters/dragon.svg',
  'assets/story/characters/fox.svg',
  'assets/story/characters/fairy.svg',
  'assets/story/moods/funny.svg',
  'assets/story/moods/adventurous.svg',
  'assets/story/moods/spooky.svg',
  'assets/story/moods/calm.svg',
  'assets/story/settings/forest.svg',
  'assets/story/settings/ocean.svg',
  'assets/story/settings/city.svg',
  'assets/story/settings/space.svg',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every story illustration is bundled and non-empty', () async {
    for (final path in _expectedAssets) {
      final data = await rootBundle.loadString(path);
      expect(data, contains('<svg'), reason: '$path is not valid SVG');
    }
  });

  test('both font files are bundled', () async {
    for (final path in ['assets/fonts/Fredoka.ttf', 'assets/fonts/Nunito.ttf']) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(10000), reason: '$path too small');
    }
  });
}
