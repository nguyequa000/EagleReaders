import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/child_profiles.dart';
import 'child_profile_screen.dart';
import 'parent_settings_screen.dart';
import 'rewards_manager_screen.dart';

/// Parent-facing dashboard: family reading stats + recent activity feed
/// ([ActivityService]), real child profiles ([ChildProfileStore]) and rewards.
///
/// Activity is still keyed by child display name, matching the reader.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key, this.store});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final ChildProfileStore? store;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  List<ChildProfile>? _children;
  List<(String, ActivityEvent)> _activity = [];
  ChildActivityStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<ChildProfile> children;
    try {
      children = await _store.load();
    } catch (_) {
      children = [];
    }
    final activity = <(String, ActivityEvent)>[];
    var books = 0, minutes = 0, stories = 0;
    for (final child in children) {
      final events = await ActivityService.instance.getEvents(child.name);
      final stats = await ActivityService.instance.getStats(child.name);
      activity.addAll(events.map((e) => (child.name, e)));
      books += stats.booksFinished;
      minutes += stats.minutesThisWeek;
      stories += stats.storiesCreated;
    }
    activity.sort((a, b) => a.$2.ts.compareTo(b.$2.ts));
    if (!mounted) return;
    setState(() {
      _children = children;
      _activity = activity;
      _stats = ChildActivityStats(
        booksFinished: books,
        minutesThisWeek: minutes,
        storiesCreated: stories,
        lastComprehensionScorePct: null,
      );
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
                    ..._buildChildProfiles(),
                    const SizedBox(height: 20),

                    // Rewards (CR #2)
                    const Text(
                      'Rewards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRewardsEntry(context),
                    const SizedBox(height: 20),

                    const Text(
                      'Family\'s Recent Activity',
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
                      for (final (name, event) in _activity.reversed.take(
                        8,
                      )) ...[
                        _buildActivityItem(event.describe(name)),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRewardsEntry(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.redeem, color: Colors.white),
        ),
        title: const Text('Manage Rewards'),
        subtitle: const Text('Set what your children can spend coins on'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RewardsManagerScreen())),
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

  /// The "Child Profiles" rows: real profiles from the local store once loaded,
  /// an empty-state row if there are none, nothing while still loading.
  List<Widget> _buildChildProfiles() {
    final children = _children;
    if (children == null) return const [];
    if (children.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: const Text(
            'No child profiles yet.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      ];
    }
    final rows = <Widget>[];
    for (final child in children) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(_buildChildProfile(child));
    }
    return rows;
  }

  Widget _buildChildProfile(ChildProfile child) {
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
            child: Text(child.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Text(
            child.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildProfileScreen(childName: child.name),
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
