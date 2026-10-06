import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/story_option.dart';
import 'package:storysprout/screens/story/story_option_grid.dart';
import 'package:storysprout/screens/story/story_theme.dart';

void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    String? selected,
    ValueChanged<String>? onSelect,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryOptionGrid(
            options: StoryOptions.moods,
            selectedLabel: selected,
            accent: StoryPalette.light.action,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The decorated layers of one tile, outermost first.
  ///
  /// A tile is two boxes: the selection halo, which is laid out always and
  /// only painted when chosen, and the sticker itself, which carries the tint,
  /// the ink line and the shadow. Tests have to say which one they mean.
  List<BoxDecoration> layersFor(WidgetTester tester, String label) {
    return tester
        .widgetList<Container>(
          find.descendant(
            of: find.ancestor(
              of: find.text(label),
              matching: find.byType(GestureDetector),
            ),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .toList();
  }

  BoxDecoration haloFor(WidgetTester tester, String label) =>
      layersFor(tester, label).first;

  BoxDecoration stickerFor(WidgetTester tester, String label) =>
      layersFor(tester, label)[1];

  testWidgets('renders a tile for every option', (tester) async {
    await pumpGrid(tester);
    for (final option in StoryOptions.moods) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

  testWidgets('reports the tapped label', (tester) async {
    String? picked;
    await pumpGrid(tester, onSelect: (label) => picked = label);

    await tester.tap(find.text('Spooky'));
    await tester.pump();

    expect(picked, 'Spooky');
  });

  testWidgets('shows a check badge only on the selected tile', (tester) async {
    await pumpGrid(tester, selected: 'Calm');
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows no check badge before a selection is made', (
    tester,
  ) async {
    await pumpGrid(tester);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('each tile renders its own distinct SVG asset', (tester) async {
    await pumpGrid(tester);

    final pictures = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(pictures.length, StoryOptions.moods.length);

    final renderedAssets = pictures
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toSet();
    final expectedAssets = StoryOptions.moods
        .map((option) => option.asset)
        .toSet();

    expect(renderedAssets, expectedAssets);
  });

  testWidgets('shadow collapses on the pressed tile only', (tester) async {
    await pumpGrid(tester);

    expect(stickerFor(tester, 'Spooky').boxShadow, isNotEmpty);
    expect(stickerFor(tester, 'Funny').boxShadow, isNotEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Spooky')),
    );
    await tester.pump();

    expect(stickerFor(tester, 'Spooky').boxShadow, isEmpty);
    // A sibling tile's press state is untouched.
    expect(stickerFor(tester, 'Funny').boxShadow, isNotEmpty);

    await gesture.up();
    await tester.pump();

    expect(stickerFor(tester, 'Spooky').boxShadow, isNotEmpty);
  });

  testWidgets("the selected tile's ring uses the given accent", (tester) async {
    await pumpGrid(tester, selected: 'Calm');

    // Selection lives on the halo: accent when chosen, invisible otherwise.
    expect(
      haloFor(tester, 'Calm').border!.top.color,
      StoryPalette.light.action,
    );
    expect(haloFor(tester, 'Calm').border!.top.width, StoryTheme.ringWidth);
    expect(haloFor(tester, 'Funny').border!.top.color, Colors.transparent);

    // The ink line is constant, so an unchosen tile still reads as cut out
    // rather than as an unfinished version of the chosen one.
    for (final label in <String>['Calm', 'Funny']) {
      expect(
        stickerFor(tester, label).border!.top.color,
        StoryPalette.light.outline,
        reason: '$label lost its ink line',
      );
    }
  });

  testWidgets('choosing a tile does not resize it', (tester) async {
    // The halo is laid out whether or not it is painted; if it were added
    // only on selection the grid would shift under the child's finger.
    await pumpGrid(tester);
    final before = tester.getSize(
      find
          .ancestor(of: find.text('Calm'), matching: find.byType(Container))
          .first,
    );

    await pumpGrid(tester, selected: 'Calm');
    expect(
      tester.getSize(
        find
            .ancestor(of: find.text('Calm'), matching: find.byType(Container))
            .first,
      ),
      before,
    );
  });

  testWidgets('announces a tile label once, not twice', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpGrid(tester, selected: 'Funny');

    // The tile wraps its own Text in a Semantics node. Without
    // excludeSemantics the two merge and a screen reader says
    // "Funny, Funny, selected, button".
    expect(
      find.bySemanticsLabel('Funny'),
      findsOneWidget,
      reason: 'the tile must contribute exactly one labelled node',
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Funny'));
    expect(node.label, 'Funny');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    // The SvgPicture used to leak this onto the tile node. A tile is a button.
    expect(node.flagsCollection.isImage, isFalse);

    handle.dispose();
  });

  testWidgets('every tile contributes exactly one semantics node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpGrid(tester);

    for (final option in StoryOptions.moods) {
      expect(
        find.bySemanticsLabel(option.label),
        findsOneWidget,
        reason: '"${option.label}" must not be announced twice',
      );
    }

    handle.dispose();
  });

  // excludeSemantics discards the child GestureDetector's tap action, so the
  // Semantics node has to declare its own. A child using a screen reader must
  // be able to pick an option, not merely hear it read out — so assert the
  // action actually selects, rather than only that the flag is present.
  testWidgets('a screen reader can actually select a tile', (tester) async {
    final handle = tester.ensureSemantics();
    String? picked;
    await pumpGrid(tester, onSelect: (label) => picked = label);

    final node = tester.getSemantics(find.bySemanticsLabel('Spooky'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('Spooky'));
    await tester.pump();

    expect(picked, 'Spooky');
    handle.dispose();
  });
}
