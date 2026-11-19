import 'package:flutter/material.dart';

import 'child_dashboard_screen.dart';
import 'pin_lockout.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';
import '../services/child_profiles.dart';
import '../services/pin_attempts.dart';

class ChildPinScreen extends StatefulWidget {
  final ChildProfile child;

  const ChildPinScreen({super.key, required this.child});

  @override
  State<ChildPinScreen> createState() => _ChildPinScreenState();
}

class _ChildPinScreenState extends State<ChildPinScreen>
    with PinLockout<ChildPinScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;

  @override
  String get pinAttemptsKey => PinAttempts.child(widget.child.id);

  Future<void> _submit() async {
    if (await checkLock() || !mounted) return;
    if (widget.child.verifyPin(_pin.text)) {
      await pinSucceeded();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChildDashboardScreen(
            childId: widget.child.id,
            childName: widget.child.name,
          ),
        ),
      );
    } else {
      final locked = await pinFailed();
      if (!mounted) return;
      _pin.clear();
      setState(() => _error = locked ? null : 'Incorrect PIN. Try again.');
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StickerPinPage(
      title: 'Hi ${widget.child.name}!',
      emoji: '🔑',
      emojiTint: StoryTheme.of(context).tintBlue,
      prompt: 'Enter your PIN, ${widget.child.name}!',
      controller: _pin,
      error: lockMessage ?? _error,
      enabled: !isLocked,
      buttonLabel: "Let's Go! 🚀",
      onChanged: (_) => setState(() => _error = null),
      onSubmit: _submit,
    );
  }
}
