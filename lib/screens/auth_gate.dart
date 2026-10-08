import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/session_prefs.dart';
import 'login_screen.dart';
import 'parent_or_child_screen.dart';

/// The app's first screen: decides whether this device is still signed in.
///
/// Firebase Auth keeps a session on every device, so the same account can be
/// open on a phone and a tablet at once. Whether launching the app skips the
/// login screen is the parent's choice, made with "Keep me signed in":
///
/// - kept: straight to "Who is reading today?", where the parent or child PIN
///   is still asked for — signing in to the account never unlocks a profile;
/// - not kept: the saved session is ended and the login screen opens with the
///   email filled in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.auth, this.prefs});

  /// Injectable for tests; defaults to [FirebaseAuth.instance].
  final FirebaseAuth? auth;

  /// Injectable for tests; defaults to the device's shared preferences.
  final SessionPrefs? prefs;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  late final SessionPrefs _prefs = widget.prefs ?? SessionPrefs();
  late final Future<bool> _signedIn = _restore();

  Future<bool> _restore() async {
    // The first event, not currentUser: on the web the saved session is
    // restored asynchronously, and currentUser is null until it has been.
    final user = await _auth.authStateChanges().first;
    if (user == null) return false;
    if (await _prefs.keepSignedIn()) return true;
    await _auth.signOut();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _signedIn,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🌱', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.green),
                ],
              ),
            ),
          );
        }
        // An error restoring the session is treated as signed out: the login
        // screen is always a safe place to land.
        return snapshot.data == true
            ? const ParentOrChildScreen()
            : LoginScreen(auth: widget.auth, prefs: widget.prefs);
      },
    );
  }
}
