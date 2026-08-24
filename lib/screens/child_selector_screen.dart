import 'package:flutter/material.dart';
import 'child_pin_screen.dart';

class ChildSelectorScreen extends StatelessWidget {
  const ChildSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who are you?'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pick your name!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // DEMO: only one child works for now
            _ChildButton(
              name: 'Alex',
              emoji: '🧒',
              enabled: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChildPinScreen(childName: 'Alex'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Disabled placeholders for future children
            _ChildButton(name: 'Sam', emoji: '👦', enabled: false),
            const SizedBox(height: 16),
            _ChildButton(name: 'Mia', emoji: '👧', enabled: false),
          ],
        ),
      ),
    );
  }
}

class _ChildButton extends StatelessWidget {
  final String name;
  final String emoji;
  final bool enabled;
  final VoidCallback? onTap;

  const _ChildButton({
    required this.name,
    required this.emoji,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Card(
        elevation: enabled ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.amber.withOpacity(0.15),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Text(name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (enabled)
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}