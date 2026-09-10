import 'package:flutter/material.dart';

import 'child_dashboard_screen.dart';
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
    if (_pin.text == widget.child.pin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChildDashboardScreen(childName: widget.child.name),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi ${widget.child.name}!'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔑', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Enter your PIN, ${widget.child.name}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 16),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Let\'s Go! 🚀',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
