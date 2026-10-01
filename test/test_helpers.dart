import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:storysprout/services/activity_service.dart';
import 'package:storysprout/services/child_profiles.dart';

/// In-memory Firebase fakes with a parent already signed in, which is the
/// state every child-profile screen assumes (the parent logs in before either
/// persona is chosen — see the screen graph in CLAUDE.md).
///
/// Screens reach activity through `ActivityService.instance`, so tests that
/// render them should assign `fb.activity` to it first.
({
  ChildProfileStore store,
  ActivityService activity,
  FakeFirebaseFirestore firestore,
  MockFirebaseAuth auth,
})
signedIn({String uid = 'parent-1'}) {
  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
  final firestore = FakeFirebaseFirestore();
  return (
    store: ChildProfileStore(firestore: firestore, auth: auth),
    activity: ActivityService(firestore: firestore, auth: auth),
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
}) async {
  final snapshot = await firestore
      .collection('parents')
      .doc(uid)
      .collection('children')
      .doc(childId)
      .collection('activity')
      .orderBy('ts')
      .get();
  return [for (final doc in snapshot.docs) doc.data()];
}
