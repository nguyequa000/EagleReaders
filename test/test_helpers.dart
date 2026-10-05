import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/coin_service.dart';

/// In-memory Firebase fakes with a parent already signed in, which is the
/// state every child-profile screen assumes (the parent logs in before either
/// persona is chosen — see the screen graph in CLAUDE.md).
///
/// Screens reach activity through `ActivityService.instance` and coins
/// through `CoinService.instance`, so tests that render them should assign
/// `fb.activity` / `fb.coins` first.
({
  ChildProfileStore store,
  ActivityService activity,
  CoinService coins,
  FakeFirebaseFirestore firestore,
  MockFirebaseAuth auth,
})
signedIn({String uid = 'parent-1'}) {
  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
  final firestore = FakeFirebaseFirestore();
  return (
    store: ChildProfileStore(firestore: firestore, auth: auth),
    activity: ActivityService(firestore: firestore, auth: auth),
    coins: CoinService(firestore: firestore, auth: auth),
    firestore: firestore,
    auth: auth,
  );
}

/// Raw activity documents for [childId] under the default test parent, oldest
/// first — for asserting on exactly what was written.
Future<List<Map<String, dynamic>>> activityDocs(
  FakeFirebaseFirestore firestore,
  String childId, {
  String uid = 'parent-1',
}) => _docs(firestore, childId, 'activity', uid);

/// Raw coin ledger rows for [childId], oldest first.
Future<List<Map<String, dynamic>>> ledgerDocs(
  FakeFirebaseFirestore firestore,
  String childId, {
  String uid = 'parent-1',
}) => _docs(firestore, childId, 'coinLedger', uid);

Future<List<Map<String, dynamic>>> _docs(
  FakeFirebaseFirestore firestore,
  String childId,
  String collection,
  String uid,
) async {
  final snapshot = await firestore
      .collection('parents')
      .doc(uid)
      .collection('children')
      .doc(childId)
      .collection(collection)
      .orderBy('ts')
      .get();
  return [for (final doc in snapshot.docs) doc.data()];
}
