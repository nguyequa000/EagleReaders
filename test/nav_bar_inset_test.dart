import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storysprout/screens/child_pin_screen.dart';
import 'package:storysprout/screens/login_screen.dart';
import 'package:storysprout/screens/parent_settings_screen.dart';
import 'package:storysprout/screens/story/story_button.dart';
import 'package:storysprout/screens/story_flow_screen.dart';
import 'package:storysprout/services/child_profiles.dart';
import 'package:storysprout/services/family_settings.dart';

/// Android 15 draws apps edge to edge, so a 3-button navigation bar (Samsung
/// One UI) sits over the bottom of the app. Every screen must keep its
/// controls above it.
void main() {
  // A phone like the Galaxy S21: 360 x 800 dp at 3x, with a 48 dp nav bar.
  const navBar = 48.0;
  const height = 800.0;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  void useS21(WidgetTester tester) {
    tester.view.physicalSize = const Size(360 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(
      top: 24 * 3,
      bottom: navBar * 3,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: 24 * 3,
      bottom: navBar * 3,
    );
    addTearDown(tester.view.reset);
  }

  void expectAboveNavBar(WidgetTester tester, Finder finder) {
    expect(finder, findsOneWidget);
    expect(
      tester.getRect(finder).bottom,
      lessThanOrEqualTo(height - navBar),
      reason: 'drawn under the navigation bar',
    );
  }

  Finder button(String label) => find.widgetWithText(StoryButton, label);

  /// The screen's scrolling body: nothing in it can scroll under the bar.
  Finder body() => find.byType(Scrollable).first;

  testWidgets('PIN screen: the page stops above the nav bar', (tester) async {
    useS21(tester);
    final child = ChildProfile.withPin(id: '1', name: 'Mika', pin: '4321');
    await tester.pumpWidget(MaterialApp(home: ChildPinScreen(child: child)));
    await tester.pumpAndSettle();

    expectAboveNavBar(tester, body());
    expectAboveNavBar(tester, button("Let's Go! 🚀"));
  });

  testWidgets('login: Register clears the nav bar', (tester) async {
    useS21(tester);
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(auth: MockFirebaseAuth())),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    expectAboveNavBar(tester, body());
    expectAboveNavBar(tester, button('New here? Register'));
  });

  testWidgets('story flow: Next and the progress bar clear the nav bar', (
    tester,
  ) async {
    useS21(tester);
    await tester.pumpWidget(const MaterialApp(home: StoryFlowScreen()));
    await tester.pumpAndSettle();

    expectAboveNavBar(tester, button('Next'));
    // The step dots are the last thing on the page.
    expectAboveNavBar(
      tester,
      find
          .ancestor(
            of: find.textContaining('STEP 1 OF'),
            matching: find.byType(Padding),
          )
          .first,
    );
  });

  testWidgets('settings: the end of the list clears the nav bar', (
    tester,
  ) async {
    useS21(tester);
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'parent-1', email: 'p@example.com'),
    );
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: ParentSettingsScreen(
          auth: auth,
          settings: FamilySettings(firestore: firestore, auth: auth),
          store: ChildProfileStore(firestore: firestore, auth: auth),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expectAboveNavBar(tester, button('Sign Out'));
  });
}
