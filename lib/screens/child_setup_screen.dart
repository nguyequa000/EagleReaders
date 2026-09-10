import 'package:flutter/material.dart';

import '../services/child_profiles.dart';
import 'parent_dashboard_screen.dart';

/// Shown once, right after a parent creates their account: how many children,
/// and a name + 4-digit PIN for each. Saved locally via [ChildProfileStore].
class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key});

  static const int maxChildren = 6;

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _pinCtrls = [];
  int _count = 1;
  bool _saving = false;
  String? _error;

  static final RegExp _pinPattern = RegExp(r'^\d{4}$');

  @override
  void initState() {
    super.initState();
    _setCount(1);
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _pinCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _setCount(int n) {
    while (_nameCtrls.length < n) {
      _nameCtrls.add(TextEditingController());
      _pinCtrls.add(TextEditingController());
    }
    while (_nameCtrls.length > n) {
      _nameCtrls.removeLast().dispose();
      _pinCtrls.removeLast().dispose();
    }
    setState(() {
      _count = n;
      _error = null;
    });
  }

  Future<void> _save() async {
    final names = [for (final c in _nameCtrls) c.text.trim()];
    final pins = [for (final c in _pinCtrls) c.text];

    if (names.any((n) => n.isEmpty) ||
        pins.any((p) => !_pinPattern.hasMatch(p))) {
      setState(() => _error = 'Give each child a name and a 4-digit PIN.');
      return;
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final profiles = [
      for (var i = 0; i < names.length; i++)
        ChildProfile(id: '${now}_$i', name: names[i], pin: pins[i]),
    ];

    setState(() {
      _saving = true;
      _error = null;
    });
    await ChildProfileStore.save(profiles);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Children'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      // Scrollable so the dynamic rows + keyboard don't overflow (see CLAUDE.md).
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Set up a profile and PIN for each child on this account.',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'How many children?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _count,
                        onChanged: _saving
                            ? null
                            : (val) {
                                if (val != null) _setCount(val);
                              },
                        items: [
                          for (
                            var n = 1;
                            n <= ChildSetupScreen.maxChildren;
                            n++
                          )
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _count; i++) _childCard(i),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Done', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _childCard(int i) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Child ${i + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrls[i],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrls[i],
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-digit PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
    );
  }
}
