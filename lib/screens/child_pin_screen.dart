import 'package:flutter/material.dart';

import 'child_dashboard_screen.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';
import '../services/child_profiles.dart';

class ChildPinScreen extends StatefulWidget {
  final ChildProfile child;

  const ChildPinScreen({super.key, required this.child});

  @override
  State<ChildPinScreen> createState() => _ChildPinScreenState();
}

class _ChildPinScreenState extends State<ChildPinScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;

  void _submit() {
    if (widget.child.verifyPin(_pin.text)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChildDashboardScreen(
            childId: widget.child.id,
            childName: widget.child.name,
          ),
        ),
      );
    } else {
      setState(() => _error = 'Incorrect PIN. Try again.');
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
      error: _error,
      buttonLabel: "Let's Go! 🚀",
      onChanged: (_) => setState(() => _error = null),
      onSubmit: _submit,
    );
  }
}
