import 'package:flutter/material.dart';
import 'parent_dashboard_screen.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

class ParentPinScreen extends StatefulWidget {
  const ParentPinScreen({super.key});

  @override
  State<ParentPinScreen> createState() => _ParentPinScreenState();

  // DEMO: hardcoded pin for testing. Also unlocks a child's daily time limit.
  static const String parentPin = '1234';
}

class _ParentPinScreenState extends State<ParentPinScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;

  void _submit() {
    if (_pin.text == ParentPinScreen.parentPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
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
      title: 'Parent Login',
      emoji: '👨‍👩‍👧',
      emojiTint: StoryTheme.of(context).tintGreen,
      prompt: 'Enter your PIN',
      controller: _pin,
      error: _error,
      buttonLabel: 'Enter',
      onChanged: (_) => setState(() => _error = null),
      onSubmit: _submit,
    );
  }
}
