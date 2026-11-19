import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'sticker_kit.dart';
import 'story/story_theme.dart';

/// "Forgot password?" from the login screen: Firebase emails a reset link.
///
/// Pops `true` once the request went through. The message never says whether
/// an account uses that email, so the dialog can't be used to find out.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.auth,
    this.initialEmail = '',
  });

  final FirebaseAuth auth;

  /// Whatever was already typed in the login screen's email field.
  final String initialEmail;

  /// The note shown after a reset email was requested.
  static const String sentMessage =
      "If an account uses that email, a reset link is on its way. "
      'Check your inbox.';

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.sendPasswordResetEmail(email: email);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      // Without email enumeration protection Firebase says when no account
      // exists; treat that as sent so the answer is always the same.
      if (e.code == 'user-not-found') {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(e.code);
      });
    }
  }

  static String _messageFor(String code) => switch (code) {
    'invalid-email' => "That doesn't look like a valid email.",
    'network-request-failed' =>
      'No connection. Check your network and try again.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    _ => "We couldn't send the email. Please try again.",
  };

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(
            "We'll email you a link to choose a new password.",
            style: StoryTheme.body(size: 14, color: palette.inkMuted),
          ),
          TextField(
            key: const Key('reset-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: StoryTheme.body(color: palette.ink),
            decoration: stickerInputDecoration(palette, label: 'Email'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: StickerErrorNote(_error!),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}
