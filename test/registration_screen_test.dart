import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_setup_screen.dart';
import 'package:storysprout/screens/registration_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('successful registration writes a parent doc to Firestore '
      '(TC-FB-WB-001)', (tester) async {
    final auth = MockFirebaseAuth();
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      wrap(RegistrationScreen(auth: auth, firestore: firestore)),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'newparent@example.com',
    );
    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    final uid = auth.currentUser!.uid;
    final doc = await firestore.collection('parents').doc(uid).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['role'], 'parent');
    expect(doc.data()!['email'], 'newparent@example.com');
    expect(find.byType(ChildSetupScreen), findsOneWidget);
  });

  testWidgets('email-already-in-use shows an error and does not navigate', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    final firestore = FakeFirebaseFirestore();
    whenCalling(
      Invocation.method(#createUserWithEmailAndPassword, null),
    ).on(auth).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await tester.pumpWidget(
      wrap(RegistrationScreen(auth: auth, firestore: firestore)),
    );
    await tester.enterText(find.byType(TextField).first, 'taken@example.com');
    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pumpAndSettle();

    expect(
      find.text('An account with that email already exists.'),
      findsOneWidget,
    );
    expect(find.byType(ChildSetupScreen), findsNothing);
  });

  testWidgets('short password is rejected before any auth call', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(
      wrap(RegistrationScreen(auth: auth, firestore: firestore)),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'newparent@example.com',
    );
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    expect(auth.currentUser, isNull);
  });
}
