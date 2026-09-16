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

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StoryOptionGrid(
          options: StoryOptions.moods,
          selectedLabel: selected,
          accent: StoryTheme.accentCharacter,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    ));
    await tester.pump();
  }

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

  testWidgets('shows no check badge before a selection is made', (tester) async {
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
    final expectedAssets =
        StoryOptions.moods.map((option) => option.asset).toSet();

    expect(renderedAssets, expectedAssets);
  });

  testWidgets('shadow collapses on the pressed tile only', (tester) async {
    await pumpGrid(tester);

    BoxDecoration decorationFor(String label) {
      return tester
          .widget<Container>(
            find
                .descendant(
                  of: find.ancestor(
                    of: find.text(label),
                    matching: find.byType(GestureDetector),
                  ),
                  matching: find.byType(Container),
                )
                .first,
          )
          .decoration! as BoxDecoration;
    }

    expect(decorationFor('Spooky').boxShadow, isNotEmpty);
    expect(decorationFor('Funny').boxShadow, isNotEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Spooky')),
    );
    await tester.pump();

    expect(decorationFor('Spooky').boxShadow, isEmpty);
    // A sibling tile's press state is untouched.
    expect(decorationFor('Funny').boxShadow, isNotEmpty);

    await gesture.up();
    await tester.pump();

    expect(decorationFor('Spooky').boxShadow, isNotEmpty);
  });

  testWidgets('the selected tile\'s ring uses the given accent', (tester) async {
    await pumpGrid(tester, selected: 'Calm');

    final decoration = tester
        .widget<Container>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text('Calm'),
                  matching: find.byType(GestureDetector),
                ),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration! as BoxDecoration;

    expect(decoration.border!.top.color, StoryTheme.accentCharacter);
    expect(decoration.border!.top.width, StoryTheme.ringWidth);

    final unselected = tester
        .widget<Container>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text('Funny'),
                  matching: find.byType(GestureDetector),
                ),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration! as BoxDecoration;
    expect(unselected.border!.top.color, StoryTheme.shadow);
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
