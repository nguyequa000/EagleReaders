import 'package:flutter/material.dart';
import 'parent_dashboard_screen.dart';

class ParentPinScreen extends StatefulWidget {
  const ParentPinScreen({super.key});

  @override
  State<ParentPinScreen> createState() => _ParentPinScreenState();
}

class _ParentPinScreenState extends State<ParentPinScreen> {
  final TextEditingController _pin = TextEditingController();
  String? _error;

  // DEMO: hardcoded pin for testing
  static const String _demoPin = '1234';

  void _submit() {
    if (_pin.text == _demoPin) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Login'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍👩‍👧', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Enter your PIN',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Enter', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}