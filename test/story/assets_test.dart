import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';

/// Every bundled illustration, listed literally.
///
/// [StoryCharacters] has its own test that walks the catalog and loads whatever
/// it names. This list is the other half of that check: it fails when an asset
/// is dropped from pubspec.yaml or from disk, including one the catalog has
/// also stopped naming.
const _expectedAssets = <String>[
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

  test('every Kenney pet is bundled', () async {
    for (final path in HeroCatalog.petAssets) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(200), reason: '$path too small');
    }
  });

  test('both font files are bundled', () async {
    for (final path in [
      'assets/fonts/Fredoka.ttf',
      'assets/fonts/Nunito.ttf',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(10000), reason: '$path too small');
    }
  });
}
