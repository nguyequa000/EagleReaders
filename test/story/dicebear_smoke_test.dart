import 'package:dicebear_core/dicebear_core.dart';
import 'package:dicebear_styles/avataaars.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the avatar engine behaves the way the hero builder needs it to,
/// before any UI is built on top of it.
///
/// This is foundation cover, not feature cover: if DiceBear ever stops
/// generating offline, stops being deterministic, or renames the option keys,
/// the builder breaks in ways that are hard to read from a widget failure.
void main() {
  late Style style;

  setUp(() => style = Style.parse(avataaars));

  test('generates a valid SVG with no network access', () {
    final avatar = Avatar(style, {'seed': 'Maya', 'size': 200});
    expect(avatar.svg, startsWith('<svg'));
    expect(avatar.svg, contains('</svg>'));
    expect(avatar.svg.length, greaterThan(500));
  });

  test('is deterministic for a seed', () {
    final a = Avatar(style, {'seed': 'Maya', 'size': 200}).svg;
    final b = Avatar(style, {'seed': 'Maya', 'size': 200}).svg;
    expect(a, b);
  });

  test('different seeds give different heroes — this is Randomize', () {
    final a = Avatar(style, {'seed': 'Maya', 'size': 200}).svg;
    final b = Avatar(style, {'seed': 'Leo', 'size': 200}).svg;
    expect(a, isNot(b));
  });

  test('a chosen variant actually changes the render', () {
    final base = Avatar(style, {'seed': 'Maya', 'size': 200}).svg;
    final hatted = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'topVariant': <String>['turban'],
    }).svg;
    expect(hatted, isNot(base));

    // Pinning the same single variant twice must be stable, or the option
    // strip would show one thing and the preview another.
    final again = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'topVariant': <String>['turban'],
    }).svg;
    expect(again, hatted);
  });

  test('a chosen colour actually lands in the output', () {
    // Assert the colour is *present*, not merely that the render differs. A
    // difference test passes by accident when the seed already happened to
    // pick the colour being pinned, which is exactly what bit the first
    // version of this test.
    final teal = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'clothesColor': <String>['2a8c82'],
    }).svg;
    expect(teal, contains('#2a8c82'));
  });

  test('colours are accepted with or without a leading hash', () {
    // The catalogue stores swatches as '#614335' but the HTTP API takes bare
    // hex. The builder reads swatches straight from the catalogue, so the
    // hashed form is the one that has to work.
    final hashed = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'clothesColor': <String>['#2a8c82'],
    }).svg;
    final bare = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'clothesColor': <String>['2a8c82'],
    }).svg;
    expect(hashed, contains('#2a8c82'));
    expect(hashed, bare);
  });

  test('every avatar carries its own attribution metadata', () {
    // DiceBear embeds RDF provenance in the SVG itself, so each rendered hero
    // names its creator and licence without the app doing anything. This is
    // the credit trail for a licence whose canonical page no longer loads.
    final svg = Avatar(style, {'seed': 'Maya', 'size': 200}).svg;
    expect(svg, contains('Pablo Stanley'));
    expect(svg, contains('Free for personal and commercial use'));
  });

  test('variant and colour compose without fighting each other', () {
    final both = Avatar(style, {
      'seed': 'Maya',
      'size': 200,
      'topVariant': <String>['bigHair'],
      'hairColor': <String>['4a312c'],
      'clothesVariant': <String>['hoodie'],
      'clothesColor': <String>['ff488e'],
    }).svg;
    expect(both, startsWith('<svg'));
    expect(
      both,
      isNot(Avatar(style, {'seed': 'Maya', 'size': 200}).svg),
    );
  });

  group('catalogue enumeration — what fills the option strips', () {
    Map<String, Object?> sectionOf(String key) =>
        style.definition()[key] as Map<String, Object?>;

    test('components expose their variants by name', () {
      final components = sectionOf('components');
      expect(components.keys, contains('top'));
      expect(components.keys, contains('clothes'));

      final top = components['top'] as Map<String, Object?>;
      final variants = (top['variants'] as Map<String, Object?>).keys.toList();

      // The numbers the design was sized against. If these move, the strips
      // still build — but the wireframe's row counts no longer hold.
      expect(variants, hasLength(34));
      expect(variants, contains('turban'));
      expect(variants, contains('bigHair'));
    });

    test('colours expose real swatch values', () {
      final colors = sectionOf('colors');
      expect(colors.keys, containsAll(<String>['hair', 'clothes', 'skin']));

      final skin = colors['skin'] as Map<String, Object?>;
      final swatches = skin['values'] as List<Object?>;
      expect(swatches, hasLength(7));
      for (final swatch in swatches) {
        expect(swatch, isA<String>());
        // Stored hashed — the colour row can bind these straight to a swatch
        // without reformatting.
        expect(swatch as String, matches(RegExp(r'^#[0-9a-fA-F]{6}$')));
      }
    });

    test('every wireframe row except pet has a source in the catalogue', () {
      final components = (style.definition()['components'] as Map).keys.toSet();
      expect(components, contains('top'), reason: 'hair and hat');
      expect(components, contains('clothes'), reason: 'outfit');
      expect(components, contains('eyes'), reason: 'face');
      expect(components, contains('mouth'), reason: 'face');

      // Stated as a test so the gap is recorded rather than remembered:
      // pets come from Kenney, not from here.
      expect(components, isNot(contains('pet')));
    });
  });
}
