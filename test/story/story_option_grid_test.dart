import 'package:flutter/material.dart';
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
          options: StoryOptions.characters,
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
    for (final option in StoryOptions.characters) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

  testWidgets('reports the tapped label', (tester) async {
    String? picked;
    await pumpGrid(tester, onSelect: (label) => picked = label);

    await tester.tap(find.text('Clever Fox'));
    await tester.pump();

    expect(picked, 'Clever Fox');
  });

  testWidgets('shows a check badge only on the selected tile', (tester) async {
    await pumpGrid(tester, selected: 'Magic Fairy');
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
    expect(pictures.length, StoryOptions.characters.length);

    final renderedAssets = pictures
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toSet();
    final expectedAssets =
        StoryOptions.characters.map((option) => option.asset).toSet();

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

    expect(decorationFor('Clever Fox').boxShadow, isNotEmpty);
    expect(decorationFor('Brave Knight').boxShadow, isNotEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Clever Fox')),
    );
    await tester.pump();

    expect(decorationFor('Clever Fox').boxShadow, isEmpty);
    // A sibling tile's press state is untouched.
    expect(decorationFor('Brave Knight').boxShadow, isNotEmpty);

    await gesture.up();
    await tester.pump();

    expect(decorationFor('Clever Fox').boxShadow, isNotEmpty);
  });

  testWidgets('the selected tile\'s ring uses the given accent', (tester) async {
    await pumpGrid(tester, selected: 'Magic Fairy');

    final decoration = tester
        .widget<Container>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text('Magic Fairy'),
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
                  of: find.text('Brave Knight'),
                  matching: find.byType(GestureDetector),
                ),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration! as BoxDecoration;
    expect(unselected.border!.top.color, StoryTheme.shadow);
  });
}
