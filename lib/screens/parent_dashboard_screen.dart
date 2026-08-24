import 'package:flutter/material.dart';
import 'parent_settings_screen.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            _buildProfileHeader(context),
            const SizedBox(height: 20),

            // Reading Stats
            const Text('Reading Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildReadingStats(),
            const SizedBox(height: 20),

            // Child Profiles
            const Text('Child Profiles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildChildProfile('Alex'),
            const SizedBox(height: 8),
            _buildChildProfile('Sam'),
            const SizedBox(height: 20),

            // Recent Activity
            const Text('Family\'s Recent Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildActivityItem('Alex read "The Tiny Seed"'),
            const SizedBox(height: 8),
            _buildActivityItem('Alex created "Dragon Adventure"'),
            const SizedBox(height: 8),
            _buildActivityItem('Sam read "A Bear Called Paddington"'),
            const SizedBox(height: 8),
            _buildActivityItem('Sam created "Space Explorer"'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, User',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Parent Account',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ParentSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingStats() {
    return Row(
      children: [
        _StatCard(label: 'Books Read', value: '7'),
        const SizedBox(width: 8),
        _StatCard(label: 'Minutes Read\nThis Week', value: '142'),
        const SizedBox(width: 8),
        _StatCard(label: 'Stories\nCreated', value: '4'),
      ],
    );
  }

  Widget _buildChildProfile(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.amber.withOpacity(0.2),
            child: const Text('🧒', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Text(name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(activity, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}