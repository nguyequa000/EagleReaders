import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/coin_service.dart';
import 'package:storysprout/services/rewards_store.dart';

import 'test_helpers.dart';

void main() {
  var fb = signedIn();
  late RewardStore rewards;

  setUp(() {
    fb = signedIn();
    rewards = RewardStore(firestore: fb.firestore, auth: fb.auth);
  });

  Future<Map<String, dynamic>?> childDoc(String id) async =>
      (await fb.firestore
              .collection('parents')
              .doc('parent-1')
              .collection('children')
              .doc(id)
              .get())
          .data();

  group('earning', () {
    test('a quiz writes an earn row and bumps the cached balance', () async {
      expect(await fb.coins.awardQuiz('1', 'Alice'), CoinService.coinsPerQuiz);
      expect(await fb.coins.awardStory('1', 'Dragon in Forest'), 5);

      final rows = await ledgerDocs(fb.firestore, '1');
      expect(rows, hasLength(2));
      expect(rows[0]['type'], 'earn');
      expect(rows[0]['reason'], 'quiz');
      expect(rows[0]['title'], 'Alice');
      expect(rows[0]['amount'], 5);
      expect(rows[0]['balanceAfter'], 5);
      expect(rows[1]['reason'], 'story');
      expect(rows[1]['balanceAfter'], 10);
      expect(await fb.coins.balance('1'), 10);
      expect((await childDoc('1'))?['coinBalance'], 10);
    });

    test('earning does not disturb the child profile fields', () async {
      await fb.store.save([
        ChildProfile.withPin(id: '1', name: 'Mika', pin: '1234'),
      ]);
      await fb.coins.awardQuiz('1', 'Alice');
      expect((await childDoc('1'))?['name'], 'Mika');
      expect((await childDoc('1'))?['pinHash'], isNotNull);
      // A later profile save (rename) must not wipe the balance either.
      await fb.store.save([
        ChildProfile.withPin(id: '1', name: 'Mika R', pin: '1234'),
      ]);

      final doc = await childDoc('1');
      expect(doc?['name'], 'Mika R');
      expect(doc?['coinBalance'], 5);
    });

    test('signed out: earning returns 0 and writes nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final coins = CoinService(firestore: firestore, auth: MockFirebaseAuth());
      expect(await coins.awardQuiz('1', 'Alice'), 0);
      expect(await coins.balance('1'), 0);
      expect(await coins.ledger('1'), isEmpty);
      expect((await firestore.collection('parents').get()).docs, isEmpty);
    });

    test('a balance with no earnings yet is 0', () async {
      expect(await fb.coins.balance('nobody'), 0);
    });
  });

  group('redeeming', () {
    Future<void> earn(int times) async {
      for (var i = 0; i < times; i++) {
        await fb.coins.awardQuiz('1', 'Alice');
      }
    }

    test('deducts at once and leaves a pending row', () async {
      await earn(3); // 15
      final reward = await rewards.create(title: 'Sticker', coinCost: 10);

      final tx = await fb.coins.redeem('1', reward.id);

      expect(tx.isPending, isTrue);
      expect(tx.cost, 10);
      expect(tx.balanceAfter, 5);
      expect(await fb.coins.balance('1'), 5);
      final rows = await ledgerDocs(fb.firestore, '1');
      expect(rows.last['type'], 'redeem');
      expect(rows.last['amount'], -10);
      expect(rows.last['status'], 'pending');
      expect(rows.last['rewardId'], reward.id);
      expect(rows.last['title'], 'Sticker');
    });

    test(
      'uses the cost stored now, not one the child loaded earlier',
      () async {
        await earn(2); // 10
        final reward = await rewards.create(title: 'Sticker', coinCost: 5);
        await rewards.update(reward.id, title: 'Sticker', coinCost: 20);

        await expectLater(
          fb.coins.redeem('1', reward.id),
          throwsA(
            isA<InsufficientCoinsError>().having(
              (e) => e.message,
              'message',
              'You need 10 more coins for that one.',
            ),
          ),
        );
        expect(await fb.coins.balance('1'), 10);
      },
    );

    test('not enough coins: throws and writes nothing', () async {
      await earn(1); // 5
      final reward = await rewards.create(title: 'Ice cream', coinCost: 50);

      await expectLater(
        fb.coins.redeem('1', reward.id),
        throwsA(isA<InsufficientCoinsError>()),
      );
      expect(await ledgerDocs(fb.firestore, '1'), hasLength(1));
      expect(await fb.coins.balance('1'), 5);
    });

    test('a retired or missing reward cannot be redeemed', () async {
      await earn(4);
      final reward = await rewards.create(title: 'Sticker', coinCost: 5);
      await rewards.setActive(reward.id, false);

      await expectLater(
        fb.coins.redeem('1', reward.id),
        throwsA(isA<RewardUnavailableError>()),
      );
      await expectLater(
        fb.coins.redeem('1', 'no-such-reward'),
        throwsA(isA<RewardUnavailableError>()),
      );
      expect(await fb.coins.balance('1'), 20);
    });

    test('two redeems in a row cannot overspend', () async {
      await earn(2); // 10
      final reward = await rewards.create(title: 'Sticker', coinCost: 10);

      await fb.coins.redeem('1', reward.id);
      await expectLater(
        fb.coins.redeem('1', reward.id),
        throwsA(isA<InsufficientCoinsError>()),
      );
      expect(await fb.coins.balance('1'), 0);
    });

    test('signed out: redeem throws', () async {
      final coins = CoinService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      expect(() => coins.redeem('1', 'r'), throwsStateError);
    });
  });

  group('parent follow-up', () {
    Future<CoinTransaction> pendingSticker() async {
      await fb.coins.awardQuiz('1', 'Alice');
      await fb.coins.awardQuiz('1', 'Alice');
      final reward = await rewards.create(title: 'Sticker', coinCost: 10);
      return fb.coins.redeem('1', reward.id);
    }

    test(
      'mark as given closes the request and keeps the coins spent',
      () async {
        final tx = await pendingSticker();

        await fb.coins.markGiven('1', tx.id);

        final redemptions = await fb.coins.redemptions('1');
        expect(redemptions.single.status, 'given');
        expect(redemptions.single.resolvedAt, isNotNull);
        expect(await fb.coins.balance('1'), 0);
        await expectLater(
          fb.coins.markGiven('1', tx.id),
          throwsA(isA<CoinError>()),
        );
      },
    );

    test('decline refunds the coins with a refund row, once', () async {
      final tx = await pendingSticker();

      await fb.coins.decline('1', tx.id);

      expect(await fb.coins.balance('1'), 10);
      final rows = await ledgerDocs(fb.firestore, '1');
      final refund = rows.last;
      expect(refund['type'], 'refund');
      expect(refund['amount'], 10);
      expect(refund['balanceAfter'], 10);
      expect(refund['redeemId'], tx.id);
      expect((await fb.coins.redemptions('1')).single.status, 'declined');

      await expectLater(
        fb.coins.decline('1', tx.id),
        throwsA(isA<CoinError>()),
      );
      expect(await fb.coins.balance('1'), 10);
    });

    test('balanceAfter on every row follows the running total', () async {
      final tx = await pendingSticker();
      await fb.coins.decline('1', tx.id);
      await fb.coins.awardStory('1', 'Dragon');

      var running = 0;
      for (final row in await fb.coins.ledger('1')) {
        running += row.amount;
        expect(row.balanceAfter, running);
      }
      expect(await fb.coins.balance('1'), running);
    });
  });

  group('feed and notifications', () {
    test('ledger rows read as parent-facing feed lines', () async {
      await fb.coins.awardQuiz('1', 'Alice');
      await fb.coins.awardStory('1', 'Dragon in Forest');
      final reward = await rewards.create(title: 'Sticker', coinCost: 10);
      final tx = await fb.coins.redeem('1', reward.id);
      await fb.coins.decline('1', tx.id);

      final lines = [
        for (final row in await fb.coins.ledger('1'))
          row.toActivityEvent().describe('Mika'),
      ];
      expect(lines, [
        'Mika earned 5 coins for a quiz on "Alice"',
        'Mika earned 5 coins for creating "Dragon in Forest"',
        'Mika redeemed "Sticker" for 10 coins',
        'Mika got 10 coins back for "Sticker"',
      ]);
    });

    test('watchPending reports new redemptions across children', () async {
      final children = [
        ChildProfile.withPin(id: '1', name: 'Mika', pin: '1234'),
        ChildProfile.withPin(id: '2', name: 'Salma', pin: '1234'),
      ];
      for (final child in children) {
        await fb.coins.awardQuiz(child.id, 'Alice');
      }
      final reward = await rewards.create(title: 'Sticker', coinCost: 5);

      final seen = <List<String>>[];
      final sub = fb.coins
          .watchPending(children)
          .listen(
            (pending) => seen.add([
              for (final p in pending) '${p.childName}:${p.transaction.title}',
            ]),
          );
      await pumpEventQueue();
      expect(seen.last, isEmpty);

      final tx = await fb.coins.redeem('2', reward.id);
      await pumpEventQueue();
      expect(seen.last, ['Salma:Sticker']);

      await fb.coins.markGiven('2', tx.id);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await sub.cancel();
    });
  });

  test('removing a child deletes its coin ledger', () async {
    await fb.store.save([
      ChildProfile.withPin(id: '1', name: 'Mika', pin: '1234'),
      ChildProfile.withPin(id: '2', name: 'Salma', pin: '1234'),
    ]);
    await fb.coins.awardQuiz('1', 'Alice');
    await fb.coins.awardQuiz('2', 'Alice');

    await fb.store.save([
      ChildProfile.withPin(id: '2', name: 'Salma', pin: '1234'),
    ]);

    expect(await ledgerDocs(fb.firestore, '1'), isEmpty);
    expect(await ledgerDocs(fb.firestore, '2'), hasLength(1));
  });
}
