import 'package:flutter/material.dart';

import '../services/rewards_store.dart';

/// What a child can work toward (CR #2): the rewards their parent has set up,
/// cheapest first.
///
/// No balance is shown yet — nothing in the app awards coins, so any number
/// here would be invented. The balance and a Redeem button land with the coin
/// ledger, once reading sessions can be turned into earnings.
class ChildRewardsScreen extends StatefulWidget {
  const ChildRewardsScreen({super.key, required this.childName, this.store});

  final String childName;

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final RewardStore? store;

  @override
  State<ChildRewardsScreen> createState() => _ChildRewardsScreenState();
}

class _ChildRewardsScreenState extends State<ChildRewardsScreen> {
  late final RewardStore _store = widget.store ?? RewardStore();
  List<Reward>? _rewards;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Reward> rewards;
    try {
      rewards = await _store.load(activeOnly: true);
    } catch (_) {
      rewards = [];
    }
    if (mounted) setState(() => _rewards = rewards);
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
                  Text(
                    rewards.isEmpty
                        ? 'Nothing here yet, ${widget.childName}!'
                        : 'Keep reading to earn coins, ${widget.childName}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (rewards.isEmpty)
                    const _NoRewardsYet()
                  else
                    ...rewards.map((r) => _RewardTile(reward: r)),
                ],
              ),
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
  const _RewardTile({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
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
    );
  }
}
