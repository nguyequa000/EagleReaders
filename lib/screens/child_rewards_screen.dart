import 'package:flutter/material.dart';

import '../services/coin_service.dart';
import '../services/rewards_store.dart';
import 'live_refresh.dart';
import 'sticker_kit.dart';
import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_row_label.dart';
import 'story/story_theme.dart';

/// What a child can work toward (CR #2): their coin balance, the rewards their
/// parent has set up (cheapest first) with a Redeem button on each one they
/// can afford, and the requests they have already made.
class ChildRewardsScreen extends StatefulWidget {
  const ChildRewardsScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.store,
    this.coins,
  });

  final String childId;
  final String childName;

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final RewardStore? store;

  /// Injectable for tests; defaults to [CoinService.instance].
  final CoinService? coins;

  @override
  State<ChildRewardsScreen> createState() => _ChildRewardsScreenState();
}

class _ChildRewardsScreenState extends State<ChildRewardsScreen>
    with LiveRefresh {
  late final RewardStore _store = widget.store ?? RewardStore();
  late final CoinService _coins = widget.coins ?? CoinService.instance;
  List<Reward>? _rewards;
  int _balance = 0;
  List<CoinTransaction> _requests = [];
  String? _error;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
    // The parent can add or retire rewards, and give or decline requests,
    // from their own device while this screen is open.
    refreshOn(() => [_store.changes(), _coins.changes(widget.childId)], _load);
  }

  Future<void> _load() async {
    List<Reward> rewards;
    try {
      rewards = await _store.load(activeOnly: true);
    } catch (_) {
      rewards = [];
    }
    var balance = 0;
    var requests = <CoinTransaction>[];
    try {
      balance = await _coins.balance(widget.childId);
      requests = await _coins.redemptions(widget.childId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rewards = rewards;
      _balance = balance;
      _requests = requests;
    });
  }

  Future<void> _redeem(Reward reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StickerDialog(
        emoji: '🎁',
        title: 'Get "${reward.title}"?',
        message: 'This spends ${reward.coinCost} of your $_balance coins.',
        primaryLabel: 'Yes, redeem!',
        onPrimary: () => Navigator.pop(context, true),
        secondaryLabel: 'Not yet',
        onSecondary: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _error = null;
      _redeeming = true;
    });
    try {
      await _coins.redeem(widget.childId, reward.id);
    } on CoinError catch (e) {
      if (mounted) setState(() => _error = e.message);
      await _load();
      if (mounted) setState(() => _redeeming = false);
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Try again in a moment.';
          _redeeming = false;
        });
      }
      return;
    }
    await _load();
    if (!mounted) return;
    setState(() => _redeeming = false);
    await showDialog<void>(
      context: context,
      builder: (context) => _StickerDialog(
        emoji: '🎉',
        title: 'You did it!',
        message: 'You redeemed "${reward.title}". Your grown-up has been told!',
        primaryLabel: 'Yay!',
        onPrimary: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final rewards = _rewards;

    return Scaffold(
      backgroundColor: palette.ground,
      body: PaperBackground(
        child: Column(
          children: [
            const StickerHeader(
              title: 'My Rewards',
              showBack: true,
              trailing: [ThemeSticker()],
            ),
            Expanded(
              child: rewards == null
                  ? Center(
                      child: CircularProgressIndicator(color: palette.action),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: palette.action,
                      child: ListView(
                        // Extra room right and below for the hard shadows.
                        padding: const EdgeInsets.fromLTRB(20, 20, 24, 28),
                        children: [
                          _BalanceCard(
                            childName: widget.childName,
                            coins: _balance,
                          ),
                          const SizedBox(height: 22),
                          if (_error != null) ...[
                            StickerCard(
                              color: palette.tintCoral,
                              radius: StoryTheme.radiusButton,
                              depth: 3,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: StoryTheme.body(
                                  color: palette.ink,
                                  weight: 700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (rewards.isEmpty)
                            const _NoRewardsYet()
                          else
                            for (final (i, r) in rewards.indexed)
                              _RewardTile(
                                index: i,
                                reward: r,
                                balance: _balance,
                                onRedeem: _redeeming ? null : () => _redeem(r),
                              ),
                          if (_requests.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: StoryRowLabel(text: 'My requests'),
                            ),
                            const SizedBox(height: 10),
                            ..._requests.map((r) => _RequestTile(request: r)),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coin total on a yellow sticker, tipped like the dashboard's cards.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.childName, required this.coins});

  final String childName;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      color: palette.tintYellow,
      tilt: stickerTilt(0),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          StickerEmoji(emoji: '🪙', color: palette.surface, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$coins ${coins == 1 ? 'coin' : 'coins'}',
                  key: const Key('rewardsBalance'),
                  style: StoryTheme.display(
                    size: 28,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Read, finish quizzes and make stories to earn more, '
                  '$childName!',
                  style: StoryTheme.body(
                    size: 14,
                    color: palette.ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRewardsYet extends StatelessWidget {
  const _NoRewardsYet();

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      tilt: stickerTilt(1),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          StickerEmoji(emoji: '🎁', color: palette.tintMagenta, size: 72),
          const SizedBox(height: 14),
          Text(
            'Ask a grown-up to add some rewards!',
            textAlign: TextAlign.center,
            style: StoryTheme.display(size: 18, color: palette.ink),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.index,
    required this.reward,
    required this.balance,
    required this.onRedeem,
  });

  /// Position in the list, which picks the gift's tint and the card's tilt.
  final int index;
  final Reward reward;
  final int balance;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final affordable = balance >= reward.coinCost;
    final short = reward.coinCost - balance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: StickerCard(
        // Past the balance card's tilt, so neighbours lean opposite ways.
        tilt: stickerTilt(index + 1),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StickerEmoji(
                  emoji: '🎁',
                  color: palette.tintForIndex(index + 1),
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        style: StoryTheme.display(
                          size: 18,
                          color: palette.ink,
                          weight: 700,
                        ),
                      ),
                      if (reward.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          reward.description,
                          style: StoryTheme.body(
                            size: 14,
                            color: palette.inkMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StickerPill(
                  color: palette.tintYellow,
                  child: Column(
                    children: [
                      Text(
                        '${reward.coinCost}',
                        style: StoryTheme.display(
                          size: 20,
                          color: palette.ink,
                          weight: 700,
                        ),
                      ),
                      Text(
                        reward.coinCost == 1 ? 'coin' : 'coins',
                        style: StoryTheme.body(
                          size: 12,
                          color: palette.ink,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (affordable)
              StoryButton(
                label: 'Redeem',
                accent: palette.action,
                showArrow: false,
                onPressed: onRedeem,
              )
            else ...[
              _CoinProgress(value: balance / reward.coinCost),
              const SizedBox(height: 6),
              Text(
                '$short more ${short == 1 ? 'coin' : 'coins'} to go',
                style: StoryTheme.body(size: 14, color: palette.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How close the child is to a reward, drawn like the story flow's progress
/// bar: an inked track with the action colour filling it.
class _CoinProgress extends StatelessWidget {
  const _CoinProgress({required this.value});

  /// 0 to 1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Semantics(
      value: '${(value * 100).round()}%',
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: palette.track,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidthThin,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: palette.action),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final CoinTransaction request;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final (label, icon, tint) = switch (request.status) {
      'given' => ('Given', Icons.check_rounded, palette.tintGreen),
      'declined' => (
        'Not this time, coins returned',
        Icons.undo_rounded,
        palette.surface,
      ),
      _ => (
        'Waiting for a grown-up',
        Icons.hourglass_top_rounded,
        palette.tintYellow,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StickerCard(
        radius: StoryTheme.radiusButton,
        depth: 3,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.outline,
                  width: StoryTheme.outlineWidthThin,
                ),
              ),
              child: Icon(icon, color: palette.ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: StoryTheme.display(
                      size: 16,
                      color: palette.ink,
                      weight: 700,
                    ),
                  ),
                  Text(
                    label,
                    style: StoryTheme.body(size: 13, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${request.cost} 🪙',
              style: StoryTheme.display(
                size: 16,
                color: palette.ink,
                weight: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A paper sticker of a dialog: an emoji on top, then the question, then the
/// buttons stacked full width so a small finger can't miss them.
class _StickerDialog extends StatelessWidget {
  const _StickerDialog({
    required this.emoji,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String emoji;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Dialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        side: BorderSide(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: StickerEmoji(
                emoji: emoji,
                color: palette.tintYellow,
                size: 72,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: StoryTheme.display(
                size: 22,
                color: palette.ink,
                weight: 700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: StoryTheme.body(size: 16, color: palette.ink),
            ),
            const SizedBox(height: 22),
            StoryButton(
              label: primaryLabel,
              accent: palette.action,
              showArrow: false,
              onPressed: onPrimary,
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 12),
              StoryButton(
                label: secondaryLabel!,
                accent: palette.action,
                showArrow: false,
                filled: false,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
