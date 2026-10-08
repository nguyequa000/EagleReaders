import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_changes.dart';

/// A reward a parent defines for their children to redeem coins against
/// (CR #2). Stored at `parents/{uid}/rewards/{rewardId}`.
///
/// Rewards belong to the parent, not to one child: every child on the account
/// sees the same catalog. That matches the change request, where the point is
/// family-wide visibility of what everyone is working toward.
///
/// Coins have no real-money value and rewards are whatever the parent decides
/// to honour off-app — a trip for ice cream, extra screen time. Nothing here
/// touches payments, and nothing should.
class Reward {
  final String id;
  final String title;
  final String description;
  final int coinCost;

  /// Retired rewards stay in the collection so past redemptions still resolve
  /// to a title; they are just hidden from the child's catalog.
  final bool active;

  final DateTime? createdAt;

  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.coinCost,
    this.active = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'coinCost': coinCost,
    'active': active,
  };

  factory Reward.fromMap(String id, Map<String, dynamic> map) => Reward(
    id: id,
    title: (map['title'] as String?) ?? '',
    description: (map['description'] as String?) ?? '',
    coinCost: (map['coinCost'] as num?)?.toInt() ?? 0,
    active: (map['active'] as bool?) ?? true,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
  );
}

/// Thrown when a reward fails validation. The message is written to be shown
/// straight to the parent.
class RewardValidationError implements Exception {
  final String message;
  const RewardValidationError(this.message);

  @override
  String toString() => message;
}

/// The parent's reward catalog.
///
/// Mirrors `ChildProfileStore`: injectable Firestore/Auth for tests, reads
/// degrade to empty when signed out, writes throw. Lives under
/// `parents/{uid}`, so the deployed `firestore.rules` wildcard already scopes
/// it to the owning parent with no rules change.
class RewardStore {
  RewardStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Guards against a fat-fingered cost that would put a reward permanently
  /// out of reach.
  static const int maxCoinCost = 10000;

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('parents').doc(uid).collection('rewards');
  }

  CollectionReference<Map<String, dynamic>> get _requireCollection {
    final collection = _collection;
    if (collection == null) {
      throw StateError('Cannot change rewards while signed out.');
    }
    return collection;
  }

  /// Fires whenever the parent adds, edits, retires or restores a reward,
  /// from any device.
  Stream<void> changes() {
    final collection = _collection;
    if (collection == null) return const Stream.empty();
    return changesOf(collection.snapshots());
  }

  /// The catalog, cheapest first — so the child sees what is within reach
  /// before what is not.
  ///
  /// [activeOnly] is what the child's screen passes; the parent's manager
  /// wants retired rewards too so they can be brought back.
  Future<List<Reward>> load({bool activeOnly = false}) async {
    final collection = _collection;
    if (collection == null) return [];

    final snapshot = await collection.orderBy('coinCost').get();
    final rewards = [
      for (final doc in snapshot.docs) Reward.fromMap(doc.id, doc.data()),
    ];
    return activeOnly ? rewards.where((r) => r.active).toList() : rewards;
  }

  /// Creates a reward and returns it with the id Firestore assigned.
  Future<Reward> create({
    required String title,
    required int coinCost,
    String description = '',
  }) async {
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    _validate(cleanTitle, coinCost);

    final doc = _requireCollection.doc();
    await doc.set({
      'title': cleanTitle,
      'description': cleanDescription,
      'coinCost': coinCost,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return Reward(
      id: doc.id,
      title: cleanTitle,
      description: cleanDescription,
      coinCost: coinCost,
    );
  }

  /// Edits an existing reward. Merges, so `createdAt` and `active` survive.
  Future<void> update(
    String id, {
    required String title,
    required int coinCost,
    String description = '',
  }) async {
    final cleanTitle = title.trim();
    _validate(cleanTitle, coinCost);

    await _requireCollection.doc(id).set({
      'title': cleanTitle,
      'description': description.trim(),
      'coinCost': coinCost,
    }, SetOptions(merge: true));
  }

  /// Retires or restores a reward.
  ///
  /// Deliberately not a delete: once coins have been spent on a reward, the
  /// ledger row points at this document, and removing it would leave a
  /// redemption no one can identify.
  Future<void> setActive(String id, bool active) async {
    await _requireCollection.doc(id).set({
      'active': active,
    }, SetOptions(merge: true));
  }

  void _validate(String title, int coinCost) {
    if (title.isEmpty) {
      throw const RewardValidationError('Give the reward a name.');
    }
    if (coinCost <= 0) {
      throw const RewardValidationError('Cost must be at least 1 coin.');
    }
    if (coinCost > maxCoinCost) {
      throw const RewardValidationError(
        'Cost must be $maxCoinCost coins or fewer.',
      );
    }
  }
}
