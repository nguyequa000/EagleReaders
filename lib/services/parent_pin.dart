import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'child_profiles.dart';

/// The parent's 4-digit PIN: what stands between "Who is reading today?" and
/// the parent side, and what lifts a child's daily limit.
///
/// Chosen at registration and kept as a salted hash beside the other fields
/// on `parents/{uid}` (`pinHash`, `pinSalt`), hashed the same way as a
/// child's ([ChildProfile.hashPin]) and with the same caveat: a 4-digit space
/// is guessable, so `firestore.rules` is the real boundary. The plain PIN is
/// never stored, on the device or in Firestore.
class ParentPin {
  ParentPin({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  /// Shared instance the screens use. Assignable only so tests can point it
  /// at in-memory fakes before any screen touches Firebase.
  static ParentPin instance = ParentPin();

  // Resolved lazily, like FamilySettings: constructing the default instance
  // must not touch Firebase, which is not initialized in tests.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static final RegExp _shape = RegExp(r'^\d{4}$');

  /// Whether [pin] is four digits, the only shape a parent PIN can take.
  static bool isValid(String pin) => _shape.hasMatch(pin);

  /// The fields to store for [pin], for a caller that is already writing the
  /// parent document (registration).
  static Map<String, String> fieldsFor(String pin) {
    final salt = ChildProfile.newSalt();
    return {'pinHash': ChildProfile.hashPin(pin, salt), 'pinSalt': salt};
  }

  DocumentReference<Map<String, dynamic>> get _parent {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No parent is signed in.');
    }
    return _firestore.collection('parents').doc(uid);
  }

  Future<({String hash, String salt})?> _stored() async {
    final data = (await _parent.get()).data();
    final hash = data?['pinHash'] as String?;
    final salt = data?['pinSalt'] as String?;
    if (hash == null || salt == null) return null;
    return (hash: hash, salt: salt);
  }

  /// False for an account made before registration asked for a PIN.
  Future<bool> isSet() async => await _stored() != null;

  Future<bool> verify(String pin) async {
    final stored = await _stored();
    if (stored == null) return false;
    return ChildProfile.hashPin(pin, stored.salt) == stored.hash;
  }

  /// Replaces the PIN, leaving the rest of the parent document alone.
  Future<void> set(String pin) async {
    if (!isValid(pin)) throw ArgumentError.value(pin, 'pin', 'not 4 digits');
    await _parent.set(fieldsFor(pin), SetOptions(merge: true));
  }
}
