import 'package:flutter/material.dart';

import '../services/child_profiles.dart';
import '../services/coin_service.dart';
import 'live_refresh.dart';
import 'sticker_kit.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

/// Parent-facing list of rewards the children have redeemed (CR #2).
///
/// Coins leave the child's balance the moment they redeem, so each request
/// waits here as "pending" until the parent hands the reward over (Mark as
/// given) or turns it down (Decline, which refunds the coins).
class RewardRequestsScreen extends StatefulWidget {
  const RewardRequestsScreen({super.key, this.store, this.coins});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final ChildProfileStore? store;

  /// Injectable for tests; defaults to [CoinService.instance].
  final CoinService? coins;

  @override
  State<RewardRequestsScreen> createState() => _RewardRequestsScreenState();
}

typedef _Request = ({ChildProfile child, CoinTransaction tx});

class _RewardRequestsScreenState extends State<RewardRequestsScreen>
    with LiveRefresh {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  late final CoinService _coins = widget.coins ?? CoinService.instance;

  List<_Request>? _requests;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The child ids [refreshOn] is currently listening to, so a reload only
  /// re-subscribes when a child was added or removed.
  String? _watchedChildren;

  /// A redemption made on the child's device lands here without a refresh.
  void _watchChildren(List<ChildProfile> children) {
    final ids = children.map((c) => c.id).join(',');
    if (ids == _watchedChildren) return;
    _watchedChildren = ids;
    refreshOn(
      () => [_store.changes(), for (final c in children) _coins.changes(c.id)],
      _load,
    );
  }

  Future<void> _load() async {
    final requests = <_Request>[];
    try {
      final children = await _store.load();
      _watchChildren(children);
      for (final child in children) {
        for (final tx in await _coins.redemptions(child.id)) {
          requests.add((child: child, tx: tx));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load requests: $e');
    }
    requests.sort((a, b) => b.tx.ts.compareTo(a.tx.ts));
    if (mounted) setState(() => _requests = requests);
  }

  Future<void> _resolve(_Request request, {required bool give}) async {
    if (!give) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Decline this request?'),
          content: Text(
            '${request.child.name} gets their ${request.tx.cost} coins back '
            'for "${request.tx.title}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _error = null;
      _busy.add(request.tx.id);
    });
    try {
      if (give) {
        await _coins.markGiven(request.child.id, request.tx.id);
      } else {
        await _coins.decline(request.child.id, request.tx.id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    await _load();
    if (mounted) setState(() => _busy.remove(request.tx.id));
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    final pending = [...?requests?.where((r) => r.tx.isPending)];
    final history = [...?requests?.where((r) => !r.tx.isPending)];

    return StickerPage(
      title: 'Reward Requests',
      forParent: true,
      body: requests == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Extra room right and below for the hard shadows.
                padding: const EdgeInsets.fromLTRB(18, 18, 22, 28),
                children: [
                  if (_error != null) ...[
                    StickerErrorNote(_error!),
                    const SizedBox(height: 16),
                  ],
                  const StickerSectionTitle('Waiting for you'),
                  if (pending.isEmpty)
                    const _Empty('No requests right now.')
                  else
                    for (final request in pending)
                      _PendingCard(
                        request: request,
                        busy: _busy.contains(request.tx.id),
                        onGive: () => _resolve(request, give: true),
                        onDecline: () => _resolve(request, give: false),
                      ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const StickerSectionTitle('History'),
                    for (final request in history)
                      _HistoryTile(request: request),
                  ],
                ],
              ),
            ),
    );
  }
}

String _when(DateTime time) {
  final local = time.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} ${local.hour}:$minute';
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text, style: StoryTheme.body(color: palette.inkMuted)),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.request,
    required this.busy,
    required this.onGive,
    required this.onDecline,
  });

  final _Request request;
  final bool busy;
  final VoidCallback onGive;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final tx = request.tx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StickerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StickerEmoji(
                  emoji: request.child.emoji,
                  color: palette.tintYellow,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.child.name} redeemed "${tx.title}"',
                        style: StoryTheme.display(
                          size: 17,
                          color: palette.ink,
                          weight: 700,
                        ),
                      ),
                      Text(
                        '${tx.cost} coins · ${_when(tx.dateTime)}',
                        style: StoryTheme.body(
                          size: 13,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StoryButton(
                    label: 'Decline',
                    accent: palette.action,
                    filled: false,
                    showArrow: false,
                    onPressed: busy ? null : onDecline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: StoryButton(
                    label: 'Mark as given',
                    accent: palette.action,
                    showArrow: false,
                    onPressed: busy ? null : onGive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request});

  final _Request request;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final tx = request.tx;
    final given = tx.status == 'given';
    final resolved = tx.resolvedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StickerRow(
        leading: StickerIconDisc(
          icon: given ? Icons.check_rounded : Icons.undo_rounded,
          color: given ? palette.tintGreen : palette.surface,
          size: 38,
        ),
        title: '${request.child.name}: ${tx.title}',
        subtitle: [
          given ? 'Given' : 'Declined, ${tx.cost} coins refunded',
          if (resolved != null)
            _when(DateTime.fromMillisecondsSinceEpoch(resolved)),
        ].join(' · '),
        trailing: Text(
          '${tx.cost} 🪙',
          style: StoryTheme.display(size: 15, color: palette.ink, weight: 700),
        ),
      ),
    );
  }
}
