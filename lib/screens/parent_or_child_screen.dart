import 'package:flutter/material.dart';
import 'parent_pin_screen.dart';
import 'child_selector_screen.dart';

class ParentOrChildScreen extends StatelessWidget {
  const ParentOrChildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Story Sprout'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Who is reading today?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            _ProfileCard(
              emoji: '👨‍👩‍👧',
              label: 'Parent',
              color: Colors.green,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ParentPinScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              emoji: '🧒',
              label: 'Child',
              color: Colors.amber,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChildSelectorScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.15),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Text(label,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}