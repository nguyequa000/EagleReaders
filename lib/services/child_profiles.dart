import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One child on the account: a display name plus a 4-digit PIN.
///
/// The PIN is stored as a salted SHA-256 hash, never in plaintext. Note what
/// this does and does not buy us: it stops the PIN being readable by anyone who
/// opens the Firestore console or a database export, and the per-child salt
/// stops two children with the same PIN looking identical. It is *not* real
/// protection against a determined attacker who obtains the document — a
/// 4-digit space is 10,000 guesses against a fast hash. The actual access
/// boundary is `firestore.rules`, which only lets the owning parent read these
/// docs at all.
class ChildProfile {
  final String id;
  final String name;
  final String pinHash;
  final String pinSalt;
  final String emoji;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.pinHash,
    required this.pinSalt,
    this.emoji = '🧒',
  });

  /// Builds a profile from a plaintext PIN, generating a fresh random salt.
  /// This is the only place a caller should hand over a raw PIN.
  factory ChildProfile.withPin({
    required String id,
    required String name,
    required String pin,
    String emoji = '🧒',
  }) {
    final salt = _newSalt();
    return ChildProfile(
      id: id,
      name: name,
      pinHash: hashPin(pin, salt),
      pinSalt: salt,
      emoji: emoji,
    );
  }

  bool verifyPin(String pin) => hashPin(pin, pinSalt) == pinHash;

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final rng = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
    'emoji': emoji,
  };

  /// Reads a profile from stored fields. Tolerates the pre-migration shape,
  /// where the PIN was a plaintext `pin` key and there was no salt: such a
  /// profile is re-hashed on the spot so old local data still opens.
  factory ChildProfile.fromMap(String id, Map<String, dynamic> map) {
    final emoji = (map['emoji'] as String?) ?? '🧒';
    final name = (map['name'] as String?) ?? '';

    final hash = map['pinHash'] as String?;
    final salt = map['pinSalt'] as String?;
    if (hash != null && salt != null) {
      return ChildProfile(
        id: id,
        name: name,
        pinHash: hash,
        pinSalt: salt,
        emoji: emoji,
      );
    }

    return ChildProfile.withPin(
      id: id,
      name: name,
      pin: (map['pin'] as String?) ?? '',
      emoji: emoji,
    );
  }
}

/// Child profiles for the signed-in parent, stored at
/// `parents/{uid}/children/{childId}`.
///
/// Reading progress and sessions hang off each child document, so this path is
/// also the root of everything the parent dashboard reads back.
class ChildProfileStore {
  ChildProfileStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// The `shared_preferences` key profiles used to live under, kept only so
  /// [load] can migrate anyone who set up children before the Firestore move.
  static const String legacyKey = 'child_profiles';

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('parents').doc(uid).collection('children');
  }

  /// All children on the account, oldest first. Returns an empty list when no
  /// parent is signed in — the child-facing screens render their own empty
  /// state for that rather than erroring.
  Future<List<ChildProfile>> load() async {
    final collection = _collection;
    if (collection == null) return [];

    await _migrateLegacyProfiles(collection);

    final snapshot = await collection.orderBy('sortOrder').get();
    return [
      for (final doc in snapshot.docs) ChildProfile.fromMap(doc.id, doc.data()),
    ];
  }

  /// Replaces the stored set with [profiles]: writes each one and deletes any
  /// child document no longer in the list, matching the all-or-nothing
  /// semantics the setup screen expects.
  Future<void> save(List<ChildProfile> profiles) async {
    final collection = _collection;
    if (collection == null) {
      throw StateError('Cannot save child profiles while signed out.');
    }

    final batch = _firestore.batch();
    final keep = {for (final p in profiles) p.id};

    final existing = await collection.get();
    for (final doc in existing.docs) {
      if (!keep.contains(doc.id)) batch.delete(doc.reference);
    }

    for (var i = 0; i < profiles.length; i++) {
      final profile = profiles[i];
      batch.set(collection.doc(profile.id), {
        ...profile.toMap(),
        // Preserve the caller's ordering. A server timestamp would not work
        // here: within one batch they are identical, so ordering by it is
        // unstable.
        'sortOrder': i,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// One-time lift of profiles created before the Firestore move. Runs only
  /// when local data exists and the account has no children yet, so it cannot
  /// clobber profiles created on another device.
  Future<void> _migrateLegacyProfiles(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(legacyKey);
    if (raw == null || raw.isEmpty) return;

    final existing = await collection.limit(1).get();
    if (existing.docs.isNotEmpty) {
      await prefs.remove(legacyKey);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final batch = _firestore.batch();
      for (var i = 0; i < decoded.length; i++) {
        final map = decoded[i] as Map<String, dynamic>;
        final profile = ChildProfile.fromMap(map['id'] as String? ?? '$i', map);
        batch.set(collection.doc(profile.id), {
          ...profile.toMap(),
          'sortOrder': i,
        });
      }
      await batch.commit();
    } catch (_) {
      // Unreadable local data is not worth failing the screen over; the parent
      // can re-add children from the dashboard.
    }

    await prefs.remove(legacyKey);
  }
}
