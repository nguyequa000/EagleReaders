// Coin ledger and balance (CR #2).
//
// Children earn coins for finishing a quiz or creating a story, and spend
// them on rewards their parent defined (see `rewards_store.dart`). Coins have
// no real-money value and cannot be bought, transferred or cashed out.
//
// Storage: one append-only ledger per child plus a cached balance on the child
// document, both under the signed-in parent (children have no Firebase
// identity, see `firestore.rules`):
//
//   parents/{uid}/children/{childId}                  coinBalance (int)
//   parents/{uid}/children/{childId}/coinLedger/{id}
//     type          earn | redeem | refund
//     amount        signed (+5, -50, +50)
//     balanceAfter  the balance once this row applied
//     reason        quiz | story | reward
//     title         book / story / reward title
//     rewardId      redeem + refund rows
//     status        pending | given | declined   (redeem rows only)
//     redeemId      refund rows: the redeem row being reversed
//     ts            epoch millis, same clock as the activity log
//     resolvedAt    epoch millis, when the parent gave or declined
//
// Every row is written in the same transaction as the balance it produces, so
// the two cannot drift and two quick taps cannot spend the same coins twice.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_service.dart';
import 'child_profiles.dart';
import 'firestore_changes.dart';

class CoinTransaction {
  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String reason;
  final String title;
  final String? rewardId;
  final String? status;
  final String? redeemId;
  final int ts;
  final int? resolvedAt;

  const CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    required this.title,
    required this.ts,
    this.rewardId,
    this.status,
    this.redeemId,
    this.resolvedAt,
  });

  factory CoinTransaction.fromMap(String id, Map<String, dynamic> map) =>
      CoinTransaction(
        id: id,
        type: (map['type'] as String?) ?? 'earn',
        amount: (map['amount'] as num?)?.toInt() ?? 0,
        balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
        reason: (map['reason'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        rewardId: map['rewardId'] as String?,
        status: map['status'] as String?,
        redeemId: map['redeemId'] as String?,
        ts: (map['ts'] as num?)?.toInt() ?? 0,
        resolvedAt: (map['resolvedAt'] as num?)?.toInt(),
      );

  bool get isPending => type == 'redeem' && status == 'pending';

  /// The cost of a redemption, as a positive number.
  int get cost => amount.abs();

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts);

  /// This row as an activity-feed entry, so the parent dashboard can merge
  /// coin activity into the same list as reading activity.
  ActivityEvent toActivityEvent() => ActivityEvent(
    type: switch (type) {
      'redeem' => 'reward_redeemed',
      'refund' => 'coins_refunded',
      _ => 'coins_earned',
    },
    ts: ts,
    data: {'title': title, 'coins': amount.abs(), 'reason': reason},
  );
}

/// A pending redemption together with the child who made it, for the parent's
/// notification list.
class PendingRedemption {
  final String childId;
  final String childName;
  final CoinTransaction transaction;

  const PendingRedemption({
    required this.childId,
    required this.childName,
    required this.transaction,
  });
}

/// Thrown when a redemption cannot go ahead. The message is written to be
/// shown straight to the child.
class CoinError implements Exception {
  final String message;
  const CoinError(this.message);

  @override
  String toString() => message;
}

class InsufficientCoinsError extends CoinError {
  const InsufficientCoinsError(super.message);
}

class RewardUnavailableError extends CoinError {
  const RewardUnavailableError(super.message);
}

class CoinService {
  CoinService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance the screens use. Assignable only so tests can point it
  /// at in-memory fakes before any screen touches Firebase.
  static CoinService instance = CoinService();

  static const int coinsPerQuiz = 5;
  static const int coinsPerStory = 5;

  // Resolved lazily, like ActivityService: constructing the default instance
  // must not touch Firebase, which is not initialized in tests.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? _parent() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('parents').doc(uid);
  }

  DocumentReference<Map<String, dynamic>>? _childDoc(String childId) =>
      _parent()?.collection('children').doc(childId);

  CollectionReference<Map<String, dynamic>>? _ledger(String childId) =>
      _childDoc(childId)?.collection('coinLedger');

  DocumentReference<Map<String, dynamic>> _requireChild(String childId) {
    final child = _childDoc(childId);
    if (child == null) {
      throw StateError('Cannot change coins while signed out.');
    }
    return child;
  }

  static int _balanceOf(DocumentSnapshot<Map<String, dynamic>> child) =>
      (child.data()?['coinBalance'] as num?)?.toInt() ?? 0;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Writes the cached balance. `update` when the child document exists, so
  /// only `coinBalance` is touched; `set` only for a child with no profile
  /// document yet. (A merging `set` would do the same on real Firestore, but
  /// fake_cloud_firestore ignores `merge` inside transactions and would wipe
  /// the profile, so this keeps tests and production on one code path.)
  static void _writeBalance(
    Transaction tx,
    DocumentSnapshot<Map<String, dynamic>> child,
    int balance,
  ) {
    if (child.exists) {
      tx.update(child.reference, {'coinBalance': balance});
    } else {
      tx.set(child.reference, {'coinBalance': balance});
    }
  }

  /// Adds [amount] coins and returns how many were awarded. Returns 0 without
  /// writing when no parent is signed in: awards are fire-and-forget from the
  /// quiz and story screens, like activity logging.
  Future<int> earn(
    String childId, {
    required String reason,
    required String title,
    required int amount,
  }) async {
    final child = _childDoc(childId);
    if (child == null || amount <= 0) return 0;
    final row = child.collection('coinLedger').doc();
    await _firestore.runTransaction((tx) async {
      final childSnap = await tx.get(child);
      final balance = _balanceOf(childSnap) + amount;
      tx.set(row, {
        'type': 'earn',
        'amount': amount,
        'balanceAfter': balance,
        'reason': reason,
        'title': title,
        'ts': _now(),
      });
      _writeBalance(tx, childSnap, balance);
    });
    return amount;
  }

  Future<int> awardQuiz(String childId, String bookTitle) =>
      earn(childId, reason: 'quiz', title: bookTitle, amount: coinsPerQuiz);

  Future<int> awardStory(String childId, String storyTitle) =>
      earn(childId, reason: 'story', title: storyTitle, amount: coinsPerStory);

  /// Fires whenever [childId]'s balance or ledger changes — coins earned,
  /// spent, given or declined — on this device or another one.
  Stream<void> changes(String childId) {
    final child = _childDoc(childId);
    final ledger = _ledger(childId);
    if (child == null || ledger == null) return const Stream.empty();
    return mergeChanges([
      changesOf(child.snapshots()),
      changesOf(ledger.snapshots()),
    ]);
  }

  /// The child's current balance; 0 when signed out or never earned.
  Future<int> balance(String childId) async {
    final child = _childDoc(childId);
    if (child == null) return 0;
    return _balanceOf(await child.get());
  }

  /// Spends coins on [rewardId]. The coins leave the balance straight away and
  /// the row waits as `pending` until the parent gives or declines it.
  ///
  /// The reward's cost and active flag are read inside the transaction rather
  /// than taken from the caller, so a catalog the child loaded before the
  /// parent edited it cannot buy at the old price.
  Future<CoinTransaction> redeem(String childId, String rewardId) async {
    final child = _requireChild(childId);
    final rewardRef = _parent()!.collection('rewards').doc(rewardId);
    final row = child.collection('coinLedger').doc();

    return _firestore.runTransaction((tx) async {
      final rewardSnap = await tx.get(rewardRef);
      final childSnap = await tx.get(child);
      final reward = rewardSnap.data();
      if (reward == null || reward['active'] == false) {
        throw const RewardUnavailableError(
          'That reward isn\'t available any more.',
        );
      }
      final cost = (reward['coinCost'] as num?)?.toInt() ?? 0;
      final title = (reward['title'] as String?) ?? '';
      final balance = _balanceOf(childSnap);
      if (cost <= 0) {
        throw const RewardUnavailableError(
          'That reward isn\'t available any more.',
        );
      }
      if (balance < cost) {
        final short = cost - balance;
        throw InsufficientCoinsError(
          'You need $short more ${short == 1 ? 'coin' : 'coins'} for that one.',
        );
      }

      final data = {
        'type': 'redeem',
        'amount': -cost,
        'balanceAfter': balance - cost,
        'reason': 'reward',
        'title': title,
        'rewardId': rewardId,
        'status': 'pending',
        'ts': _now(),
      };
      tx.set(row, data);
      _writeBalance(tx, childSnap, balance - cost);
      return CoinTransaction.fromMap(row.id, data);
    });
  }

  /// The parent has handed the reward over.
  Future<void> markGiven(String childId, String transactionId) async {
    final row = _requireChild(
      childId,
    ).collection('coinLedger').doc(transactionId);
    await _firestore.runTransaction((tx) async {
      final current = CoinTransaction.fromMap(
        transactionId,
        (await tx.get(row)).data() ?? const {},
      );
      if (!current.isPending) {
        throw const CoinError('This request has already been handled.');
      }
      tx.update(row, {'status': 'given', 'resolvedAt': _now()});
    });
  }

  /// The parent turned the request down: the coins go back to the child as a
  /// `refund` row, keeping the ledger append-only.
  Future<void> decline(String childId, String transactionId) async {
    final child = _requireChild(childId);
    final row = child.collection('coinLedger').doc(transactionId);
    final refund = child.collection('coinLedger').doc();
    await _firestore.runTransaction((tx) async {
      final current = CoinTransaction.fromMap(
        transactionId,
        (await tx.get(row)).data() ?? const {},
      );
      final childSnap = await tx.get(child);
      final balance = _balanceOf(childSnap);
      if (!current.isPending) {
        throw const CoinError('This request has already been handled.');
      }
      final now = _now();
      tx.update(row, {'status': 'declined', 'resolvedAt': now});
      tx.set(refund, {
        'type': 'refund',
        'amount': current.cost,
        'balanceAfter': balance + current.cost,
        'reason': 'reward',
        'title': current.title,
        'rewardId': current.rewardId,
        'redeemId': transactionId,
        'ts': now,
      });
      _writeBalance(tx, childSnap, balance + current.cost);
    });
  }

  /// Every row for the child, oldest first. Empty when signed out.
  Future<List<CoinTransaction>> ledger(String childId) async {
    final ledger = _ledger(childId);
    if (ledger == null) return [];
    final snapshot = await ledger.orderBy('ts').get();
    return [
      for (final doc in snapshot.docs)
        CoinTransaction.fromMap(doc.id, doc.data()),
    ];
  }

  /// The child's redemptions, newest first.
  ///
  /// Filtered here and sorted in Dart: a `where` on one field plus an
  /// `orderBy` on another would need a composite index.
  Future<List<CoinTransaction>> redemptions(String childId) async {
    final ledger = _ledger(childId);
    if (ledger == null) return [];
    final snapshot = await ledger.where('type', isEqualTo: 'redeem').get();
    return [
      for (final doc in snapshot.docs)
        CoinTransaction.fromMap(doc.id, doc.data()),
    ]..sort((a, b) => b.ts.compareTo(a.ts));
  }

  /// Live list of pending redemptions across [children], oldest first. Emits
  /// once every child's listener has reported, then on every change.
  Stream<List<PendingRedemption>> watchPending(List<ChildProfile> children) {
    final ledgers = {for (final child in children) child: ?_ledger(child.id)};
    if (ledgers.isEmpty) return Stream.value(const []);

    final byChild = <String, List<PendingRedemption>>{};
    final subscriptions = <StreamSubscription<Object?>>[];
    late final StreamController<List<PendingRedemption>> controller;

    void emit() {
      if (byChild.length < ledgers.length) return;
      final all = [for (final list in byChild.values) ...list]
        ..sort((a, b) => a.transaction.ts.compareTo(b.transaction.ts));
      controller.add(all);
    }

    controller = StreamController<List<PendingRedemption>>(
      onListen: () {
        for (final MapEntry(key: child, value: ledger) in ledgers.entries) {
          subscriptions.add(
            ledger
                .where('type', isEqualTo: 'redeem')
                .where('status', isEqualTo: 'pending')
                .snapshots()
                .listen((snapshot) {
                  byChild[child.id] = [
                    for (final doc in snapshot.docs)
                      PendingRedemption(
                        childId: child.id,
                        childName: child.name,
                        transaction: CoinTransaction.fromMap(
                          doc.id,
                          doc.data(),
                        ),
                      ),
                  ];
                  emit();
                }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }
}
