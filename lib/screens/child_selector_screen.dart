import 'package:flutter/material.dart';

import 'child_pin_screen.dart';
import '../services/child_profiles.dart';

class ChildSelectorScreen extends StatefulWidget {
  const ChildSelectorScreen({super.key});

  @override
  State<ChildSelectorScreen> createState() => _ChildSelectorScreenState();
}

class _ChildSelectorScreenState extends State<ChildSelectorScreen> {
  List<ChildProfile>? _children;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await ChildProfileStore.load();
    if (mounted) setState(() => _children = children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who are you?'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Padding(padding: const EdgeInsets.all(24), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final children = _children;
    if (children == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    if (children.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌱', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'No child profiles yet.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Ask a parent to add them.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Pick your name!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        for (final child in children) ...[
          _ChildButton(
            name: child.name,
            emoji: child.emoji,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChildPinScreen(child: child)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ChildButton extends StatelessWidget {
  final String name;
  final String emoji;
  final VoidCallback onTap;

  const _ChildButton({
    required this.name,
    required this.emoji,
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
                backgroundColor: Colors.amber.withOpacity(0.15),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
