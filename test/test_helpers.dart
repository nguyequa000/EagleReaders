import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:storysprout/services/child_profiles.dart';

/// In-memory Firebase fakes with a parent already signed in, which is the
/// state every child-profile screen assumes (the parent logs in before either
/// persona is chosen — see the screen graph in CLAUDE.md).
({
  ChildProfileStore store,
  FakeFirebaseFirestore firestore,
  MockFirebaseAuth auth,
})
signedIn({String uid = 'parent-1'}) {
  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid));
  final firestore = FakeFirebaseFirestore();
  return (
    store: ChildProfileStore(firestore: firestore, auth: auth),
    firestore: firestore,
    auth: auth,
  );
}
