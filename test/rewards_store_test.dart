import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storysprout/services/rewards_store.dart';

({RewardStore store, FakeFirebaseFirestore firestore}) signedIn({
  String uid = 'parent-1',
}) {
  final firestore = FakeFirebaseFirestore();
  return (
    store: RewardStore(
      firestore: firestore,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    ),
    firestore: firestore,
  );
}

RewardStore signedOut() => RewardStore(
  firestore: FakeFirebaseFirestore(),
  auth: MockFirebaseAuth(signedIn: false),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('create', () {
    test('writes under the parent document', () async {
      final ctx = signedIn();

      final reward = await ctx.store.create(
        title: 'Ice cream',
        coinCost: 50,
        description: 'Saturday treat',
      );

      final doc = await ctx.firestore
          .doc('parents/parent-1/rewards/${reward.id}')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['title'], 'Ice cream');
      expect(doc.data()!['coinCost'], 50);
      expect(doc.data()!['description'], 'Saturday treat');
      expect(doc.data()!['active'], isTrue, reason: 'new rewards are visible');
    });

    test('returns the reward with its assigned id', () async {
      final ctx = signedIn();

      final reward = await ctx.store.create(title: 'Park trip', coinCost: 20);

      expect(reward.id, isNotEmpty);
      expect(reward.title, 'Park trip');
      expect(reward.coinCost, 20);
    });

    test('trims surrounding whitespace', () async {
      final ctx = signedIn();

      final reward = await ctx.store.create(
        title: '  Extra screen time  ',
        coinCost: 30,
        description: '  30 minutes  ',
      );

      expect(reward.title, 'Extra screen time');
      expect(reward.description, '30 minutes');
    });

    test('one parent cannot see another parent rewards', () async {
      final ctx = signedIn();
      await ctx.store.create(title: 'Ice cream', coinCost: 50);

      final other = RewardStore(
        firestore: ctx.firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'parent-2'),
        ),
      );

      expect(await other.load(), isEmpty);
    });
  });

  group('validation', () {
    test('rejects an empty or whitespace-only title', () async {
      final ctx = signedIn();

      expect(
        () => ctx.store.create(title: '', coinCost: 10),
        throwsA(isA<RewardValidationError>()),
      );
      expect(
        () => ctx.store.create(title: '   ', coinCost: 10),
        throwsA(isA<RewardValidationError>()),
      );
    });

    test('rejects a zero or negative cost', () async {
      final ctx = signedIn();

      expect(
        () => ctx.store.create(title: 'Free thing', coinCost: 0),
        throwsA(isA<RewardValidationError>()),
      );
      expect(
        () => ctx.store.create(title: 'Owed thing', coinCost: -5),
        throwsA(isA<RewardValidationError>()),
      );
    });

    test('rejects an unreachable cost', () async {
      final ctx = signedIn();

      expect(
        () => ctx.store.create(
          title: 'Pony',
          coinCost: RewardStore.maxCoinCost + 1,
        ),
        throwsA(isA<RewardValidationError>()),
      );
    });

    test('a rejected reward is not written', () async {
      final ctx = signedIn();

      try {
        await ctx.store.create(title: '', coinCost: 10);
      } catch (_) {}

      expect(await ctx.store.load(), isEmpty);
    });
  });

  group('load', () {
    test('returns rewards cheapest first', () async {
      final ctx = signedIn();
      await ctx.store.create(title: 'Big', coinCost: 300);
      await ctx.store.create(title: 'Small', coinCost: 10);
      await ctx.store.create(title: 'Medium', coinCost: 100);

      final rewards = await ctx.store.load();

      expect(rewards.map((r) => r.title), ['Small', 'Medium', 'Big']);
    });

    test('activeOnly hides retired rewards from the child', () async {
      final ctx = signedIn();
      final keep = await ctx.store.create(title: 'Keep', coinCost: 10);
      final retire = await ctx.store.create(title: 'Retire', coinCost: 20);

      await ctx.store.setActive(retire.id, false);

      expect((await ctx.store.load()).map((r) => r.title), ['Keep', 'Retire']);
      expect((await ctx.store.load(activeOnly: true)).map((r) => r.title), [
        keep.title,
      ]);
    });

    test('is empty for a parent with no rewards', () async {
      expect(await signedIn().store.load(), isEmpty);
    });
  });

  group('update and retire', () {
    test(
      'update changes fields without resurrecting a retired reward',
      () async {
        final ctx = signedIn();
        final reward = await ctx.store.create(title: 'Old', coinCost: 10);
        await ctx.store.setActive(reward.id, false);

        await ctx.store.update(reward.id, title: 'New', coinCost: 25);

        final stored = (await ctx.store.load()).single;
        expect(stored.title, 'New');
        expect(stored.coinCost, 25);
        expect(stored.active, isFalse, reason: 'retirement survives an edit');
      },
    );

    test('update enforces the same validation as create', () async {
      final ctx = signedIn();
      final reward = await ctx.store.create(title: 'Valid', coinCost: 10);

      expect(
        () => ctx.store.update(reward.id, title: '', coinCost: 10),
        throwsA(isA<RewardValidationError>()),
      );
    });

    test('retiring is reversible and never deletes the document', () async {
      final ctx = signedIn();
      final reward = await ctx.store.create(title: 'Ice cream', coinCost: 50);

      await ctx.store.setActive(reward.id, false);
      expect((await ctx.store.load()).single.active, isFalse);

      await ctx.store.setActive(reward.id, true);
      final restored = (await ctx.store.load()).single;
      expect(restored.active, isTrue);
      expect(restored.title, 'Ice cream');
    });
  });

  group('signed out', () {
    test('load returns empty rather than throwing', () async {
      expect(await signedOut().load(), isEmpty);
    });

    test('writes throw instead of landing under a wrong path', () async {
      final store = signedOut();

      expect(
        () => store.create(title: 'Ice cream', coinCost: 50),
        throwsStateError,
      );
      expect(
        () => store.update('id', title: 'Ice cream', coinCost: 50),
        throwsStateError,
      );
      expect(() => store.setActive('id', false), throwsStateError);
    });
  });
}
