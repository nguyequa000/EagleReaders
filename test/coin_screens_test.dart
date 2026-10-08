import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_rewards_screen.dart';
import 'package:storysprout/screens/comprehension_screen.dart';
import 'package:storysprout/screens/parent_dashboard_screen.dart';
import 'package:storysprout/screens/reward_requests_screen.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/rewards_store.dart';

import 'test_helpers.dart';

/// A two-question quiz to finish (chapter quizzes come from Gemini).
const _questions = [
  ComprehensionQuestion(
    question: 'What did the little seed need to grow?',
    answers: ['Water and sunlight', 'Snow and darkness', 'Wind and rocks'],
    correctIndex: 0,
  ),
  ComprehensionQuestion(
    question: 'Where did the story take place?',
    answers: ['In a city', 'In a garden', 'In the ocean'],
    correctIndex: 1,
  ),
];

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

  Future<void> earn(String childId, int times) async {
    for (var i = 0; i < times; i++) {
      await fb.coins.awardQuiz(childId, 'Alice');
    }
  }

  group('quiz', () {
    Future<void> openQuiz(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ComprehensionScreen(
                      childId: '1',
                      childName: 'Mika',
                      bookTitle: 'Alice',
                      chapterNumber: 1,
                      skippable: true,
                      questions: _questions,
                    ),
                  ),
                ),
                child: const Text('open quiz'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open quiz'));
      await tester.pumpAndSettle();
    }

    testWidgets('finishing awards coins and shows the toast', (tester) async {
      await openQuiz(tester);
      // The demo pair; one wrong answer still earns the flat amount.
      await tester.tap(find.text('Snow and darkness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Question →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In a garden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Reading →'));
      await tester.pumpAndSettle();

      expect(find.byType(ComprehensionScreen), findsNothing);
      expect(find.text('🪙 +5 coins!'), findsOneWidget);
      final rows = await ledgerDocs(fb.firestore, '1');
      expect(rows.single['reason'], 'quiz');
      expect(rows.single['amount'], CoinService.coinsPerQuiz);
      expect(await fb.coins.balance('1'), 5);
    });

    testWidgets('skipping earns nothing', (tester) async {
      await openQuiz(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(ComprehensionScreen), findsNothing);
      expect(await ledgerDocs(fb.firestore, '1'), isEmpty);
    });
  });

  group('child rewards', () {
    Future<void> openRewards(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChildRewardsScreen(
            childId: '1',
            childName: 'Mika',
            store: rewards,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the balance and only offers what it can afford', (
      tester,
    ) async {
      await earn('1', 2); // 10
      await rewards.create(title: 'Sticker', coinCost: 10);
      await rewards.create(title: 'Ice cream', coinCost: 25);
      await openRewards(tester);

      expect(find.text('10 coins'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Redeem'), findsOneWidget);
      expect(find.text('15 more coins to go'), findsOneWidget);
    });

    testWidgets('redeeming spends the coins and lists the request', (
      tester,
    ) async {
      await earn('1', 3); // 15
      await rewards.create(title: 'Sticker', coinCost: 10);
      await openRewards(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Redeem'));
      await tester.pumpAndSettle();
      expect(find.text('This spends 10 of your 15 coins.'), findsOneWidget);
      await tester.tap(find.text('Yes, redeem!'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your grown-up has been told'),
        findsOneWidget,
      );
      await tester.tap(find.text('Yay!'));
      await tester.pumpAndSettle();

      expect(find.text('5 coins'), findsOneWidget);
      expect(find.text('My requests'), findsOneWidget);
      expect(find.text('Waiting for a grown-up'), findsOneWidget);
      expect(await fb.coins.balance('1'), 5);
    });

    testWidgets('backing out of the confirm spends nothing', (tester) async {
      await earn('1', 2);
      await rewards.create(title: 'Sticker', coinCost: 10);
      await openRewards(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Redeem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();

      expect(await fb.coins.balance('1'), 10);
      expect(find.text('My requests'), findsNothing);
    });
  });

  group('parent', () {
    final mika = ChildProfile.withPin(id: '1', name: 'Mika', pin: '1234');

    testWidgets('dashboard shows balances, coin activity and the bell badge', (
      tester,
    ) async {
      await fb.store.save([mika]);
      await earn('1', 3); // 15
      final sticker = await rewards.create(title: 'Sticker', coinCost: 10);
      await fb.coins.redeem('1', sticker.id);

      await tester.pumpWidget(
        MaterialApp(home: ParentDashboardScreen(store: fb.store)),
      );
      await tester.pumpAndSettle();

      expect(find.text('🪙 5 coins'), findsOneWidget);
      expect(
        find.text('Mika earned 5 coins for a quiz on "Alice"'),
        findsNWidgets(3),
      );
      expect(find.text('Mika redeemed "Sticker" for 10 coins'), findsOneWidget);
      expect(find.text('1 waiting for you to hand over'), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a redemption made while the dashboard is open raises a banner',
      (tester) async {
        await fb.store.save([mika]);
        await earn('1', 2);
        final sticker = await rewards.create(title: 'Sticker', coinCost: 10);

        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(store: fb.store)),
        );
        await tester.pumpAndSettle();
        expect(find.text('No requests waiting'), findsOneWidget);

        await fb.coins.redeem('1', sticker.id);
        await tester.pumpAndSettle();

        expect(find.text('Mika redeemed "Sticker" (10 coins)'), findsOneWidget);
        expect(find.text('1 waiting for you to hand over'), findsOneWidget);
      },
    );

    testWidgets('requests screen marks given and declines with a refund', (
      tester,
    ) async {
      await fb.store.save([mika]);
      await earn('1', 4); // 20
      final sticker = await rewards.create(title: 'Sticker', coinCost: 5);
      final ice = await rewards.create(title: 'Ice cream', coinCost: 10);
      await fb.coins.redeem('1', sticker.id);
      await fb.coins.redeem('1', ice.id); // balance 5

      await tester.pumpWidget(
        MaterialApp(home: RewardRequestsScreen(store: fb.store)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mark as given'), findsNWidgets(2));

      final stickerCard = find.ancestor(
        of: find.text('Mika redeemed "Sticker"'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: stickerCard, matching: find.text('Mark as given')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mark as given'), findsOneWidget);
      expect(find.text('Mika: Sticker'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mika gets their 10 coins back for "Ice cream".'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Decline').last);
      await tester.pumpAndSettle();

      expect(find.text('No requests right now.'), findsOneWidget);
      expect(
        find.textContaining('Declined, 10 coins refunded'),
        findsOneWidget,
      );
      expect(await fb.coins.balance('1'), 15);
    });
  });
}
