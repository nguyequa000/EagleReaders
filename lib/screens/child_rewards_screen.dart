import 'package:flutter/material.dart';

import '../services/coin_service.dart';
import '../services/rewards_store.dart';
import 'live_refresh.dart';

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
      builder: (context) => AlertDialog(
        title: Text('Get "${reward.title}"?'),
        content: Text(
          'This spends ${reward.coinCost} of your $_balance coins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, redeem!'),
          ),
        ],
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
      builder: (context) => AlertDialog(
        title: const Text('🎉 You did it!'),
        content: Text(
          'You redeemed "${reward.title}". Your grown-up has been told!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yay!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _rewards;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('My Rewards'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: rewards == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(childName: widget.childName, coins: _balance),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (rewards.isEmpty)
                    const _NoRewardsYet()
                  else
                    ...rewards.map(
                      (r) => _RewardTile(
                        reward: r,
                        balance: _balance,
                        onRedeem: _redeeming ? null : () => _redeem(r),
                      ),
                    ),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'My requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._requests.map((r) => _RequestTile(request: r)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.childName, required this.coins});

  final String childName;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$coins ${coins == 1 ? 'coin' : 'coins'}',
                  key: const Key('rewardsBalance'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'Read, finish quizzes and make stories to earn more, '
                  '$childName!',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text('🎁', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            'Ask a grown-up to add some rewards!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.balance,
    required this.onRedeem,
  });

  final Reward reward;
  final int balance;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final affordable = balance >= reward.coinCost;
    final short = reward.coinCost - balance;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (reward.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reward.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(
                    '${reward.coinCost}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  Text(
                    reward.coinCost == 1 ? 'coin' : 'coins',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (affordable)
            ElevatedButton(
              onPressed: onRedeem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
              child: const Text('Redeem'),
            )
          else ...[
            LinearProgressIndicator(
              value: balance / reward.coinCost,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: Colors.amber,
              backgroundColor: Colors.amber.shade50,
            ),
            const SizedBox(height: 6),
            Text(
              '$short more ${short == 1 ? 'coin' : 'coins'} to go',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final CoinTransaction request;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (request.status) {
      'given' => ('Given', Icons.check_circle, Colors.green),
      'declined' => (
        'Not this time, coins returned',
        Icons.undo,
        Colors.black45,
      ),
      _ => ('Waiting for a grown-up', Icons.hourglass_top, Colors.orange),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(request.title),
        subtitle: Text(label),
        trailing: Text(
          '${request.cost} 🪙',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
