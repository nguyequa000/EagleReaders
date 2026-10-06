import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/screens/story/hero_catalog.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/coin_service.dart';

import 'test_helpers.dart';

void main() {
  /// The title the flow builds for an unbuilt hero in the Forest.
  ///
  /// Read from the catalogue rather than written out, so renaming a character
  /// cannot quietly break this the way deleting one did.
  final expectedTitle = '${HeroCatalog.heroes.first.label} in Forest';

  /// The flow's height depends on its content, so pin a size rather than
  /// leaving the 800x600 default — otherwise a layout change moves what
  /// counts as visible and these tests flap.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> completeFlow(WidgetTester tester) async {
    // Step 1 needs no choice — an unbuilt hero already draws a whole
    // character — so this stays about the bookkeeping rather than about
    // picking one. The place comes before the feeling.
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Forest');
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Funny');
    await tapVisible(tester, 'Next');
    await tapVisible(tester, 'Start Reading!');
  }

  testWidgets('Finishing the story flow records story_created for the child', (
    tester,
  ) async {
    usePhone(tester);
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;

    await tester.pumpWidget(
      const MaterialApp(home: StoryFlowScreen(childId: '1')),
    );
    await tester.pumpAndSettle();
    await completeFlow(tester);

    final docs = await activityDocs(fb.firestore, '1');
    expect(docs, hasLength(1));
    expect(docs.single['type'], 'story_created');
    expect(docs.single['title'], expectedTitle);
    expect((await fb.activity.getStats('1')).storiesCreated, 1);

    // ...and earns the story coins.
    await tester.pumpAndSettle();
    final coins = await ledgerDocs(fb.firestore, '1');
    expect(coins.single['reason'], 'story');
    expect(coins.single['amount'], CoinService.coinsPerStory);
    expect(coins.single['title'], expectedTitle);
    expect(find.text('🪙 +5 coins!'), findsOneWidget);
  });

  testWidgets('Without a child id the flow still works and logs nothing', (
    tester,
  ) async {
    usePhone(tester);
    final fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;

    await tester.pumpWidget(const MaterialApp(home: StoryFlowScreen()));
    await tester.pumpAndSettle();
    await completeFlow(tester);

    expect(find.text('Your Story'), findsOneWidget);
    final children = await fb.firestore
        .collection('parents')
        .doc('parent-1')
        .collection('children')
        .get();
    expect(children.docs, isEmpty);
  });
}
