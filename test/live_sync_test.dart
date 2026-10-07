import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_dashboard_screen.dart';
import 'package:storysprout/screens/child_rewards_screen.dart';
import 'package:storysprout/screens/child_selector_screen.dart';
import 'package:storysprout/screens/live_refresh.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/rewards_store.dart';

import 'test_helpers.dart';

/// The same account open on two devices. Each test renders a screen, then
/// writes to the shared Firestore the way the *other* device would, and checks
/// the screen catches up without being reopened.
void main() {
  // ChildProfileStore.load checks local storage for legacy profiles.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  var fb = signedIn();
  late RewardStore rewards;

  setUp(() {
    fb = signedIn();
    ActivityService.instance = fb.activity;
    CoinService.instance = fb.coins;
    rewards = RewardStore(firestore: fb.firestore, auth: fb.auth);
  });

  /// Lets a write from "the other device" reach the screen: the snapshot, the
  /// debounce, then the reload.
  Future<void> sync(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(LiveRefresh.debounce + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  testWidgets('a child added on another device appears in the selector', (
    tester,
  ) async {
    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Mika', pin: '1111'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: ChildSelectorScreen(store: fb.store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mika'), findsOneWidget);
    expect(find.text('Rae'), findsNothing);

    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Mika', pin: '1111'),
      ChildProfile.withPin(id: '2', name: 'Rae', pin: '2222'),
    ]);
    await sync(tester);

    expect(find.text('Rae'), findsOneWidget);
  });

  testWidgets('coins earned on another device update the child dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChildDashboardScreen(childId: '1', childName: 'Mika'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🪙 0'), findsOneWidget);

    await fb.coins.awardQuiz('1', 'Alice');
    await sync(tester);

    expect(find.text('🪙 ${CoinService.coinsPerQuiz}'), findsOneWidget);
  });

  group('child rewards screen', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChildRewardsScreen(
            childId: '1',
            childName: 'Mika',
            store: rewards,
            coins: fb.coins,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String balance(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('rewardsBalance'))).data!;

    testWidgets('a reward the parent adds shows up', (tester) async {
      await open(tester);
      expect(find.text('Extra bedtime story'), findsNothing);

      await rewards.create(title: 'Extra bedtime story', coinCost: 5);
      await sync(tester);

      expect(find.text('Extra bedtime story'), findsOneWidget);
    });

    testWidgets('a reward the parent retires disappears', (tester) async {
      final reward = await rewards.create(title: 'Park trip', coinCost: 5);
      await open(tester);
      expect(find.text('Park trip'), findsOneWidget);

      await rewards.setActive(reward.id, false);
      await sync(tester);

      expect(find.text('Park trip'), findsNothing);
    });

    testWidgets('a redemption made on another device updates the balance', (
      tester,
    ) async {
      final reward = await rewards.create(title: 'Sticker', coinCost: 5);
      await fb.coins.awardQuiz('1', 'Alice');
      await fb.coins.awardQuiz('1', 'Alice');
      await open(tester);
      expect(balance(tester), '10 coins');

      await fb.coins.redeem('1', reward.id);
      await sync(tester);

      expect(balance(tester), '5 coins');
    });
  });
}
