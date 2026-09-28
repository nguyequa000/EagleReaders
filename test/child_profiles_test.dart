import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/services/child_profiles.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PIN hashing', () {
    test('verifyPin accepts the right PIN and rejects the wrong one', () {
      final child = ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111');

      expect(child.verifyPin('1111'), isTrue);
      expect(child.verifyPin('2222'), isFalse);
      expect(child.verifyPin(''), isFalse);
    });

    test('the plaintext PIN is never stored', () {
      final child = ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111');

      expect(child.pinHash, isNot(contains('1111')));
      expect(child.toMap().values, isNot(contains('1111')));
      expect(child.toMap().containsKey('pin'), isFalse);
    });

    test('the same PIN hashes differently for two children', () {
      final a = ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111');
      final b = ChildProfile.withPin(id: 'b', name: 'Noah', pin: '1111');

      expect(a.pinSalt, isNot(b.pinSalt));
      expect(a.pinHash, isNot(b.pinHash));
    });
  });

  group('ChildProfileStore', () {
    test('load returns an empty list when nothing is stored', () async {
      final ctx = signedIn();
      expect(await ctx.store.load(), isEmpty);
    });

    test('save then load round-trips every field', () async {
      final ctx = signedIn();
      await ctx.store.save([
        ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111', emoji: '👧'),
        ChildProfile.withPin(id: 'b', name: 'Noah', pin: '2222'),
      ]);

      final loaded = await ctx.store.load();
      expect(loaded.length, 2);
      expect(loaded[0].id, 'a');
      expect(loaded[0].name, 'Emma');
      expect(loaded[0].emoji, '👧');
      expect(loaded[0].verifyPin('1111'), isTrue);
      expect(loaded[1].name, 'Noah');
      expect(loaded[1].emoji, '🧒'); // default
      expect(loaded[1].verifyPin('2222'), isTrue);
    });

    test('save overwrites the previous list, deleting dropped children',
        () async {
      final ctx = signedIn();
      await ctx.store.save([
        ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111'),
      ]);
      await ctx.store.save([
        ChildProfile.withPin(id: 'c', name: 'Mia', pin: '3333'),
      ]);

      final loaded = await ctx.store.load();
      expect(loaded.single.name, 'Mia');
    });

    test('profiles are scoped to the signed-in parent', () async {
      final firstParent = signedIn(uid: 'parent-1');
      await firstParent.store.save([
        ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111'),
      ]);

      // A different parent on the same Firestore instance sees nothing.
      final secondParent = ChildProfileStore(
        firestore: firstParent.firestore,
        auth: signedIn(uid: 'parent-2').auth,
      );
      expect(await secondParent.load(), isEmpty);
    });

    test('load returns empty rather than throwing when signed out', () async {
      final signedOutStore = ChildProfileStore(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(), // defaults to signed out
      );
      expect(await signedOutStore.load(), isEmpty);
    });

    test('save refuses to write while signed out', () async {
      final signedOutStore = ChildProfileStore(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      );
      expect(
        () => signedOutStore.save([
          ChildProfile.withPin(id: 'a', name: 'Emma', pin: '1111'),
        ]),
        throwsStateError,
      );
    });
  });

  group('migration from local storage', () {
    test('lifts legacy plaintext profiles into Firestore and clears them',
        () async {
      SharedPreferences.setMockInitialValues({
        ChildProfileStore.legacyKey: jsonEncode([
          {'id': 'a', 'name': 'Emma', 'pin': '1111', 'emoji': '👧'},
          {'id': 'b', 'name': 'Noah', 'pin': '2222'},
        ]),
      });

      final ctx = signedIn();
      final loaded = await ctx.store.load();

      expect(loaded.map((c) => c.name), ['Emma', 'Noah']);
      // The PIN still works, but is now hashed rather than plaintext.
      expect(loaded[0].verifyPin('1111'), isTrue);
      expect(loaded[0].pinHash, isNot('1111'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ChildProfileStore.legacyKey), isNull);
    });

    test('does not clobber children already in Firestore', () async {
      final ctx = signedIn();
      await ctx.store.save([
        ChildProfile.withPin(id: 'z', name: 'Mia', pin: '3333'),
      ]);

      SharedPreferences.setMockInitialValues({
        ChildProfileStore.legacyKey: jsonEncode([
          {'id': 'a', 'name': 'Emma', 'pin': '1111'},
        ]),
      });

      final loaded = await ctx.store.load();
      expect(loaded.map((c) => c.name), ['Mia']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ChildProfileStore.legacyKey), isNull);
    });

    test('unreadable legacy data is discarded without throwing', () async {
      SharedPreferences.setMockInitialValues({
        ChildProfileStore.legacyKey: 'not json',
      });

      final ctx = signedIn();
      expect(await ctx.store.load(), isEmpty);
    });
  });
}
