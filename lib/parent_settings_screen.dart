import 'package:flutter/material.dart';
import 'login_screen.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  bool _aiCoaching = true;
  bool _pronunciationAudio = true;
  bool _reminderNotifications = false;
  String _timeLimit = '30 minutes';

  final List<String> _timeLimitOptions = [
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    'No limit',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Parent Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            _buildProfileHeader(context),
            const SizedBox(height: 24),

            // Security Settings
            _buildSectionLabel('Security Settings'),
            _buildTappableItem('Change Email', onTap: () {}),
            const SizedBox(height: 8),
            _buildTappableItem('Change Password', onTap: () {}),
            const SizedBox(height: 24),

            // App Preferences
            _buildSectionLabel('App Preferences'),
            _buildToggleItem('AI Coaching Toggle', _aiCoaching,
                (val) => setState(() => _aiCoaching = val)),
            const SizedBox(height: 8),
            _buildToggleItem('Pronunciation Audio Toggle', _pronunciationAudio,
                (val) => setState(() => _pronunciationAudio = val)),
            const SizedBox(height: 8),
            _buildToggleItem('Reminder Notifications Toggle',
                _reminderNotifications,
                (val) => setState(() => _reminderNotifications = val)),
            const SizedBox(height: 24),

            // Content Settings
            _buildSectionLabel('Content Settings'),
            _buildTappableItem('Age Restrictions',
                trailing: const Text('Edit',
                    style: TextStyle(color: Colors.green)),
                onTap: () {}),
            const SizedBox(height: 8),
            _buildDropdownItem(),
            const SizedBox(height: 24),

            // Sign Out
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sign Out', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
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
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Parent Account',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text('Edit',
                style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTappableItem(String label,
      {Widget? trailing, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Text('Time Limit', style: TextStyle(fontSize: 15)),
          const Spacer(),
          DropdownButton<String>(
            value: _timeLimit,
            underline: const SizedBox.shrink(),
            items: _timeLimitOptions
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option,
                          style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _timeLimit = val);
            },
          ),
        ],
      ),
    );
  }
}