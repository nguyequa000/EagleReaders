import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/parent_pin.dart';
import '../services/session_prefs.dart';
import 'child_setup_screen.dart';
import 'sticker_kit.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.auth, this.firestore, this.prefs});

  /// Injectable for tests; default to the shared singletons.
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final SessionPrefs? prefs;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  late final FirebaseFirestore _firestore =
      widget.firestore ?? FirebaseFirestore.instance;
  late final TextEditingController _email;
  late final TextEditingController _password;
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _pinConfirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    final pin = _pin.text;
    if (!ParentPin.isValid(pin)) {
      setState(() => _error = 'Choose a 4-digit parent PIN.');
      return;
    }
    if (_pinConfirm.text != pin) {
      setState(() => _error = "The two PINs don't match.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      try {
        await _firestore.collection('parents').doc(cred.user!.uid).set({
          'email': cred.user!.email,
          'role': 'parent',
          'createdAt': FieldValue.serverTimestamp(),
          // Hashed; the parent PIN screen checks against it.
          ...ParentPin.fieldsFor(pin),
        });
      } on FirebaseException {
        // Firestore write failed after the account was created — roll back so
        // the user can retry cleanly.
        try {
          await cred.user?.delete();
        } catch (_) {
          // best effort
        }
        if (mounted) {
          setState(
            () => _error =
                'Could not finish setting up your account. Please try again.',
          );
        }
        return;
      }
      // A new parent stays signed in on this device, as a returning one does
      // by default; they can untick it on the login screen next time.
      await (widget.prefs ?? SessionPrefs()).save(
        keepSignedIn: true,
        email: email,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChildSetupScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'invalid-email':
        return "That doesn't look like a valid email.";
      case 'operation-not-allowed':
        return 'Email sign-up is not enabled.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    Widget field({
      required Key key,
      required TextEditingController controller,
      required String hint,
      required IconData icon,
      bool obscure = false,
      bool pin = false,
      TextInputType? keyboard,
    }) {
      return StickerFieldShadow(
        child: TextField(
          key: key,
          controller: controller,
          obscureText: obscure,
          keyboardType: pin ? TextInputType.number : keyboard,
          maxLength: pin ? 4 : null,
          style: StoryTheme.body(color: palette.ink),
          decoration: stickerInputDecoration(
            palette,
            hint: hint,
            icon: icon,
            counterText: pin ? '' : null,
          ),
        ),
      );
    }

    return StickerPromptPage(
      title: 'Register',
      emoji: '🌱',
      emojiTint: palette.tintGreen,
      prompt: 'Create an Account',
      forParent: true,
      children: [
        // The form stays square: a caret and selection drawn on a tilt are
        // hard to aim at.
        field(
          key: const Key('register-email'),
          controller: _email,
          hint: 'Email',
          icon: Icons.email,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        field(
          key: const Key('register-password'),
          controller: _password,
          hint: 'Password',
          icon: Icons.lock,
          obscure: true,
        ),
        const SizedBox(height: 24),
        Text(
          'Choose a 4-digit parent PIN. You will use it to open the parent '
          'side, so children can only reach their own.',
          style: StoryTheme.body(color: palette.inkMuted),
        ),
        const SizedBox(height: 12),
        field(
          key: const Key('register-pin'),
          controller: _pin,
          hint: 'Parent PIN',
          icon: Icons.pin,
          obscure: true,
          pin: true,
        ),
        const SizedBox(height: 16),
        field(
          key: const Key('register-pin-confirm'),
          controller: _pinConfirm,
          hint: 'Parent PIN again',
          icon: Icons.pin,
          obscure: true,
          pin: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          StickerCard(
            color: palette.tintCoral,
            radius: StoryTheme.radiusButton,
            depth: 3,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              _error!,
              style: StoryTheme.body(color: palette.ink, weight: 700),
            ),
          ),
        ],
        const SizedBox(height: 24),
        StoryButton(
          label: _loading ? 'Registering…' : 'Register',
          accent: palette.action,
          onPressed: _loading ? null : _register,
        ),
      ],
    );
  }
}
