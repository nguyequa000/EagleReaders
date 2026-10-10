import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_prefs.dart';
import 'sticker_kit.dart';
import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';
import 'registration_screen.dart';
import 'parent_or_child_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth, this.prefs});

  /// Injectable for tests; defaults to [FirebaseAuth.instance].
  final FirebaseAuth? auth;

  /// Injectable for tests; defaults to the device's shared preferences.
  final SessionPrefs? prefs;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  late final SessionPrefs _prefs = widget.prefs ?? SessionPrefs();
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _loading = false;
  String? _error;

  /// "Keep me signed in". Never covers PINs: those are asked for every time.
  bool _keepSignedIn = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
    _restoreRemembered();
  }

  /// Fills in the email and checkbox from the last sign-in on this device.
  Future<void> _restoreRemembered() async {
    final email = await _prefs.rememberedEmail();
    final keep = await _prefs.keepSignedIn();
    if (!mounted) return;
    setState(() {
      // Never clobber what the user has started typing.
      if (email != null && _email.text.isEmpty) _email.text = email;
      _keepSignedIn = keep;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _prefs.save(keepSignedIn: _keepSignedIn, email: email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentOrChildScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return "That doesn't look like a valid email.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      body: PaperBackground(
        child: Column(
          children: [
            const StickerHeader(
              title: 'Story Sprout',
              trailing: [ThemeSticker()],
            ),
            // Scrollable so the form still fits when the on-screen keyboard
            // is up and an error line is showing.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWelcome(palette),
                          const SizedBox(height: 32),
                          // The form stays square: a caret and selection
                          // drawn on a tilt are hard to aim at.
                          StickerFieldShadow(
                            child: TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: StoryTheme.body(color: palette.ink),
                              decoration: stickerInputDecoration(
                                palette,
                                hint: 'Email',
                                icon: Icons.email,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          StickerFieldShadow(
                            child: TextField(
                              controller: _password,
                              obscureText: true,
                              style: StoryTheme.body(color: palette.ink),
                              decoration: stickerInputDecoration(
                                palette,
                                hint: 'Password',
                                icon: Icons.lock,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            value: _keepSignedIn,
                            onChanged: _loading
                                ? null
                                : (value) => setState(
                                    () => _keepSignedIn = value ?? true,
                                  ),
                            title: Text(
                              'Keep me signed in',
                              style: StoryTheme.body(
                                color: palette.ink,
                                weight: 600,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: palette.action,
                            checkColor: palette.onAction,
                            side: BorderSide(
                              color: palette.outline,
                              width: StoryTheme.outlineWidthThin,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            StickerCard(
                              color: palette.tintCoral,
                              radius: StoryTheme.radiusButton,
                              depth: 3,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                _error!,
                                style: StoryTheme.body(
                                  color: palette.ink,
                                  weight: 700,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          StoryButton(
                            label: _loading ? 'Logging in…' : 'Log In',
                            accent: palette.action,
                            onPressed: _loading ? null : _login,
                          ),
                          const SizedBox(height: 16),
                          StoryButton(
                            label: 'New here? Register',
                            accent: palette.action,
                            filled: false,
                            showArrow: false,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegistrationScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sprout on a round sticker and the greeting on a tag, both a little
  /// crooked, like the story tiles.
  Widget _buildWelcome(StoryPalette palette) {
    return Column(
      children: [
        Transform.rotate(
          angle: stickerTilt(0),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: palette.tintGreen,
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidth,
              ),
              boxShadow: palette.cardShadow(),
            ),
            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 54)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        StickerCard(
          color: palette.tintYellow,
          tilt: stickerTilt(1),
          radius: StoryTheme.radiusButton,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Welcome Back!',
            style: StoryTheme.display(
              size: 26,
              color: palette.ink,
              weight: 700,
            ),
          ),
        ),
      ],
    );
  }
}
