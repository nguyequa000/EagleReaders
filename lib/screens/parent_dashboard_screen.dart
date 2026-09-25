import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import 'child_profile_screen.dart';
import 'parent_settings_screen.dart';

/// Parent-facing dashboard: reading stats + recent activity feed, backed by
/// [ActivityService].
///
/// KNOWN LIMITATION: child identity is still a bare display-name string
/// (matches the rest of the app — there is no child-profile-id system yet).
/// This screen is hardcoded to show "Alex" until real child profile
/// selection is wired in; see `child_selector_screen.dart` for where that
/// eventually needs to plug in.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  static const String _childName = 'Alex';

  List<ActivityEvent> _activity = [];
  ChildActivityStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await ActivityService.instance.getEvents(_childName);
    final stats = await ActivityService.instance.getStats(_childName);
    if (!mounted) return;
    setState(() {
      _activity = events;
      _stats = stats;
      _loading = false;
    });
  }

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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(context),
                    const SizedBox(height: 20),

                    const Text(
                      'Reading Stats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReadingStats(),
                    const SizedBox(height: 20),

                    const Text(
                      'Child Profiles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildChildProfile(_childName),
                    const SizedBox(height: 20),

                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_activity.isEmpty)
                      _buildActivityItem(
                        'No activity yet — start reading to see it here.',
                      )
                    else
                      for (final event in _activity.reversed.take(8)) ...[
                        _buildActivityItem(event.describe(_childName)),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
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
              Text(
                'Hello, User',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Parent Account',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
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
    final stats = _stats;
    return Row(
      children: [
        _StatCard(
          label: 'Books Read',
          value: (stats?.booksFinished ?? 0).toString(),
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Minutes Read\nThis Week',
          value: (stats?.minutesThisWeek ?? 0).toString(),
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Stories\nCreated',
          value: (stats?.storiesCreated ?? 0).toString(),
        ),
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
            backgroundColor: Colors.amber.withValues(alpha: 0.2),
            child: const Text('🧒', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildProfileScreen(childName: name),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
