import 'dart:async';

import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/child_profiles.dart';
import '../services/coin_service.dart';
import '../services/family_settings.dart';
import 'book_shelf_screen.dart';
import 'child_profile_screen.dart';
import 'live_refresh.dart';
import 'parent_settings_screen.dart';
import 'reward_requests_screen.dart';
import 'rewards_manager_screen.dart';

/// Parent-facing dashboard: family reading stats + recent activity feed
/// ([ActivityService]), real child profiles ([ChildProfileStore]) and rewards.
///
/// Activity is keyed by child id, so it follows the child across renames and
/// devices. Coin earnings and redemptions ([CoinService]) are merged into the
/// same feed, and a live listener on pending redemptions drives the bell's
/// badge and a banner when a child redeems while this screen is open.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key, this.store, this.coins});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final ChildProfileStore? store;

  /// Injectable for tests; defaults to [CoinService.instance].
  final CoinService? coins;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with LiveRefresh {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  late final CoinService _coins = widget.coins ?? CoinService.instance;
  List<ChildProfile>? _children;
  Map<String, int> _balances = {};
  List<PendingRedemption> _pending = [];
  StreamSubscription<List<PendingRedemption>>? _pendingSub;
  List<String> _watchedChildren = [];

  /// Pending redemptions already seen, so only new ones raise a banner.
  final Set<String> _seenPending = {};
  bool _pendingPrimed = false;
  List<(String, ActivityEvent)> _activity = [];
  ChildActivityStats? _stats;
  Map<String, ChildActivityStats> _statsByChild = {};
  bool _loading = true;

  /// What the header greets the parent as (Parent Settings → Edit).
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  /// Subscribes to pending redemptions. The first emission only primes
  /// [_seenPending]; anything that shows up after it is a fresh redemption
  /// and gets a banner.
  void _watchPending(List<ChildProfile> children) {
    _pendingSub?.cancel();
    _watchedChildren = [for (final c in children) c.id];
    final Stream<List<PendingRedemption>> stream;
    try {
      stream = _coins.watchPending(children);
    } catch (_) {
      return;
    }
    _pendingSub = stream.listen((pending) {
      if (!mounted) return;
      final fresh = [
        for (final p in pending)
          if (!_seenPending.contains(p.transaction.id)) p,
      ];
      _seenPending.addAll(fresh.map((p) => p.transaction.id));
      setState(() => _pending = pending);
      if (_pendingPrimed && fresh.isNotEmpty) {
        final p = fresh.last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${p.childName} redeemed "${p.transaction.title}" '
              '(${p.transaction.cost} coins)',
            ),
            action: SnackBarAction(label: 'View', onPressed: _openRequests),
          ),
        );
        // Their balance just dropped and the feed has a new line.
        _load();
      }
      _pendingPrimed = true;
    }, onError: (_) {});
  }

  bool _watching(List<ChildProfile> children) =>
      _pendingSub != null &&
      children.length == _watchedChildren.length &&
      children.every((c) => _watchedChildren.contains(c.id));

  Future<void> _openRequests() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RewardRequestsScreen()));
    await _load();
  }

  Future<void> _load() async {
    List<ChildProfile> children;
    try {
      children = await _store.load();
    } catch (_) {
      children = [];
    }
    final activity = <(String, ActivityEvent)>[];
    final statsByChild = <String, ChildActivityStats>{};
    final balances = <String, int>{};
    var books = 0, minutes = 0, stories = 0;
    for (final child in children) {
      List<ActivityEvent> events;
      try {
        events = await ActivityService.instance.getEvents(child.id);
      } catch (_) {
        events = [];
      }
      final stats = ActivityService.statsFrom(events);
      statsByChild[child.id] = stats;
      activity.addAll(events.map((e) => (child.name, e)));
      try {
        balances[child.id] = await _coins.balance(child.id);
        final ledger = await _coins.ledger(child.id);
        activity.addAll(ledger.map((t) => (child.name, t.toActivityEvent())));
      } catch (_) {}
      books += stats.booksFinished;
      minutes += stats.minutesThisWeek;
      stories += stats.storiesCreated;
    }
    activity.sort((a, b) => a.$2.ts.compareTo(b.$2.ts));
    String? name;
    try {
      name = await FamilySettings.instance.loadGreetingName();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _name = name;
      _children = children;
      _statsByChild = statsByChild;
      _balances = balances;
      _activity = activity;
      _stats = ChildActivityStats(
        booksFinished: books,
        minutesThisWeek: minutes,
        storiesCreated: stories,
        lastComprehensionScorePct: null,
      );
      _loading = false;
    });
    // A pull-to-refresh must not tear down a live listener for nothing.
    if (!_watching(children)) {
      _watchPending(children);
      // Stats, balances and the feed follow the children's own devices: a
      // finished book or an earned coin shows up here while it is open.
      refreshOn(
        () => [
          _store.changes(),
          FamilySettings.instance.changes(),
          for (final c in children) ...[
            ActivityService.instance.changes(c.id),
            _coins.changes(c.id),
          ],
        ],
        _load,
      );
    }
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
        actions: [
          IconButton(
            tooltip: 'Reward requests',
            onPressed: _openRequests,
            icon: Badge(
              isLabelVisible: _pending.isNotEmpty,
              label: Text('${_pending.length}'),
              child: const Icon(Icons.notifications),
            ),
          ),
        ],
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

                    const Text(
                      'Books',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildShelfEntry(context),
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
                        12,
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

  /// Manage Shelf: the family's books, imported once and given to children.
  Widget _buildShelfEntry(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(Icons.local_library, color: Colors.white),
      ),
      title: const Text('Manage Shelf'),
      subtitle: const Text('Import books and choose who reads them'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => BookShelfScreen(store: _store))),
    ),
  );

  Widget _buildRewardsEntry(BuildContext context) {
    final pending = _pending.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: pending > 0 ? Colors.orange : Colors.green,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            title: const Text('Reward Requests'),
            subtitle: Text(
              pending == 0
                  ? 'No requests waiting'
                  : '$pending waiting for you to hand over',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openRequests,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.redeem, color: Colors.white),
            ),
            title: const Text('Manage Rewards'),
            subtitle: const Text('Set what your children can spend coins on'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RewardsManagerScreen()),
            ),
          ),
        ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name == null ? 'Hello!' : 'Hello, $_name',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Parent Account',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            tooltip: 'Settings',
            // Reload on return: the name may have changed.
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ParentSettingsScreen()),
              );
              if (mounted) await _load();
            },
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
    final reading = _statsByChild[child.id]?.currentlyReading;
    final coins = _balances[child.id];
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (coins != null)
                  Text(
                    '🪙 $coins ${coins == 1 ? 'coin' : 'coins'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                if (reading != null)
                  Text(
                    'Reading: $reading',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildProfileScreen(
                  childId: child.id,
                  childName: child.name,
                ),
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
