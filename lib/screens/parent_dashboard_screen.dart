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
import 'sticker_kit.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

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
    final palette = StoryTheme.of(context);
    return StickerPage(
      title: 'Parent Dashboard',
      forParent: true,
      // The start of the parent side; back would only reach the PIN.
      allowBack: false,
      actions: [
        Badge(
          isLabelVisible: _pending.isNotEmpty,
          label: Text('${_pending.length}'),
          backgroundColor: palette.action,
          textColor: palette.onAction,
          offset: const Offset(-4, 4),
          child: StickerIconButton(
            icon: Icons.notifications,
            tooltip: 'Reward requests',
            onTap: _openRequests,
          ),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Extra room right and below for the hard shadows.
                padding: const EdgeInsets.fromLTRB(18, 18, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(context),
                    const SizedBox(height: 24),
                    const StickerSectionTitle('Reading Stats'),
                    _buildReadingStats(),
                    const SizedBox(height: 24),
                    const StickerSectionTitle('Child Profiles'),
                    ..._buildChildProfiles(),
                    const SizedBox(height: 24),
                    const StickerSectionTitle('Books'),
                    _buildShelfEntry(context),
                    const SizedBox(height: 24),
                    // Rewards (CR #2)
                    const StickerSectionTitle('Rewards'),
                    _buildRewardsEntry(context),
                    const SizedBox(height: 24),
                    const StickerSectionTitle("Family's Recent Activity"),
                    if (_activity.isEmpty)
                      _buildActivityItem(
                        'No activity yet — start reading to see it here.',
                      )
                    else
                      for (final (name, event) in _activity.reversed.take(
                        12,
                      )) ...[
                        _buildActivityItem(event.describe(name), event.type),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Manage Shelf: the family's books, imported once and given to children.
  Widget _buildShelfEntry(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerRow(
      leading: StickerIconDisc(
        icon: Icons.local_library,
        color: palette.tintGreen,
      ),
      title: 'Manage Shelf',
      subtitle: 'Import books and choose who reads them',
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => BookShelfScreen(store: _store))),
    );
  }

  Widget _buildRewardsEntry(BuildContext context) {
    final palette = StoryTheme.of(context);
    final pending = _pending.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StickerRow(
          leading: StickerIconDisc(
            icon: Icons.notifications,
            color: pending > 0 ? palette.tintCoral : palette.tintYellow,
          ),
          title: 'Reward Requests',
          subtitle: pending == 0
              ? 'No requests waiting'
              : '$pending waiting for you to hand over',
          onTap: _openRequests,
        ),
        const SizedBox(height: 10),
        StickerRow(
          leading: StickerIconDisc(
            icon: Icons.redeem,
            color: palette.tintMagenta,
          ),
          title: 'Manage Rewards',
          subtitle: 'Set what your children can spend coins on',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RewardsManagerScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          StickerIconDisc(
            icon: Icons.people_alt_outlined,
            color: palette.tintMagenta,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name == null ? 'Hello!' : 'Hello, $_name',
                  overflow: TextOverflow.ellipsis,
                  style: StoryTheme.display(
                    size: 20,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                Text(
                  'Parent Account',
                  style: StoryTheme.body(size: 13, color: palette.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: palette.ink),
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
    final palette = StoryTheme.of(context);
    final stats = _stats;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCard(
          icon: Icons.menu_book,
          color: palette.tintBlue,
          label: 'Books Read',
          value: (stats?.booksFinished ?? 0).toString(),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.schedule,
          color: palette.tintCoral,
          label: 'Minutes Read\nThis Week',
          value: (stats?.minutesThisWeek ?? 0).toString(),
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.star_outline,
          color: palette.tintMagenta,
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
      return [_buildActivityItem('No child profiles yet.')];
    }
    final rows = <Widget>[];
    for (final (i, child) in children.indexed) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(_buildChildProfile(child, i));
    }
    return rows;
  }

  Widget _buildChildProfile(ChildProfile child, int index) {
    final palette = StoryTheme.of(context);
    final reading = _statsByChild[child.id]?.currentlyReading;
    final coins = _balances[child.id];
    return StickerCard(
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          StickerEmoji(
            emoji: child.emoji,
            // Yellow and blue alternate, as in the family list mock-up.
            color: index.isEven ? palette.tintYellow : palette.tintBlue,
            size: 46,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: StoryTheme.display(
                    size: 18,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                if (coins != null)
                  Text(
                    '🪙 $coins ${coins == 1 ? 'coin' : 'coins'}',
                    style: StoryTheme.body(
                      size: 13,
                      color: palette.ink,
                      weight: 700,
                    ),
                  ),
                if (reading != null)
                  Text(
                    'Reading: $reading',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StoryTheme.body(size: 13, color: palette.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: StoryButton(
              label: 'View',
              accent: palette.action,
              showArrow: false,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildProfileScreen(
                    childId: child.id,
                    childName: child.name,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One line of the family feed, marked with what kind of thing happened:
  /// a book for reading, a pencil for a story, a gift for coins and rewards.
  Widget _buildActivityItem(String activity, [String? type]) {
    final palette = StoryTheme.of(context);
    final (icon, tint) = switch (type) {
      null => (Icons.info_outline, palette.surface),
      'story_created' => (Icons.edit, palette.tintMagenta),
      'comprehension_result' => (Icons.quiz_outlined, palette.tintGreen),
      'coins_earned' ||
      'reward_redeemed' ||
      'coins_refunded' => (Icons.redeem, palette.tintYellow),
      _ => (Icons.menu_book, palette.tintBlue),
    };
    return StickerCard(
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          StickerIconDisc(icon: icon, color: tint, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity,
              style: StoryTheme.body(size: 14, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three numbers across the top: an icon, the figure and what it
/// counts, on its own pastel sticker.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Expanded(
      child: StickerCard(
        color: color,
        radius: StoryTheme.radiusButton,
        depth: 3,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: palette.ink, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: StoryTheme.display(
                size: 26,
                color: palette.ink,
                weight: 700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: StoryTheme.body(size: 12, color: palette.ink, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
