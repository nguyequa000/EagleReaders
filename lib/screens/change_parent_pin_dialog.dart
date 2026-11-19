import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/parent_pin.dart';
import '../services/pin_attempts.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

/// Sets a new parent PIN once the account password proves it's the parent.
///
/// Opened from Parent Settings ("Change Parent PIN") and from the parent PIN
/// screen ("Forgot PIN?"), which is also the way out of a PIN lock-out: a
/// new PIN clears the wrong-guess count. Pops `true` once the PIN is saved.
class ChangeParentPinDialog extends StatefulWidget {
  const ChangeParentPinDialog({super.key, this.forgot = false});

  /// Reached from "Forgot PIN?": same fields, a title that fits.
  final bool forgot;

  @override
  State<ChangeParentPinDialog> createState() => _ChangeParentPinDialogState();
}

class _ChangeParentPinDialogState extends State<ChangeParentPinDialog> {
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty || _pin.text.isEmpty) {
      setState(() => _error = 'Fill in every field.');
      return;
    }
    if (!ParentPin.isValid(_pin.text)) {
      setState(() => _error = 'Choose 4 digits for the new PIN.');
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = "The new PINs don't match.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentPin.instance.reauthenticate(_password.text);
      await ParentPin.instance.set(_pin.text);
      await PinAttempts.instance.recordSuccess(PinAttempts.parent);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      _fail(_messageFor(e.code));
    } catch (_) {
      _fail("Couldn't save your PIN. Check your connection.");
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  static String _messageFor(String code) => switch (code) {
    'wrong-password' ||
    'invalid-credential' ||
    'user-mismatch' => 'Your password is incorrect.',
    'requires-recent-login' => 'Please sign out, sign back in, and try again.',
    'network-request-failed' =>
      'No connection. Check your network and try again.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    _ => 'Something went wrong. Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    InputDecoration pinDecoration(String label) =>
        stickerInputDecoration(palette, label: label, counterText: '');
    return AlertDialog(
      title: Text(widget.forgot ? 'Forgot your PIN?' : 'Change Parent PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            if (widget.forgot)
              Text(
                'Enter your account password to choose a new PIN.',
                style: StoryTheme.body(size: 14, color: palette.inkMuted),
              ),
            TextField(
              key: const Key('pin-account-password'),
              controller: _password,
              obscureText: true,
              style: StoryTheme.body(color: palette.ink),
              decoration: stickerInputDecoration(
                palette,
                label: 'Account password',
              ),
            ),
            TextField(
              key: const Key('new-parent-pin'),
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: StoryTheme.body(color: palette.ink),
              decoration: pinDecoration('New PIN'),
            ),
            TextField(
              key: const Key('confirm-parent-pin'),
              controller: _confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: StoryTheme.body(color: palette.ink),
              decoration: pinDecoration('Confirm new PIN'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: StickerErrorNote(_error!),
              ),
          ],
        ),
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
              : const Text('Save PIN'),
        ),
      ],
    );
  }
}
