import 'package:flutter/material.dart';

import '../services/rewards_store.dart';
import 'live_refresh.dart';

/// Parent-facing reward catalog: create rewards and set what they cost in
/// coins (CR #2). Children see the active ones on their own screen.
class RewardsManagerScreen extends StatefulWidget {
  const RewardsManagerScreen({super.key, this.store});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final RewardStore? store;

  @override
  State<RewardsManagerScreen> createState() => _RewardsManagerScreenState();
}

class _RewardsManagerScreenState extends State<RewardsManagerScreen>
    with LiveRefresh {
  late final RewardStore _store = widget.store ?? RewardStore();

  List<Reward>? _rewards;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    refreshOn(() => [_store.changes()], _load);
  }

  Future<void> _load() async {
    List<Reward> rewards;
    try {
      rewards = await _store.load();
    } catch (_) {
      rewards = [];
    }
    if (mounted) setState(() => _rewards = rewards);
  }

  Future<void> _openEditor({Reward? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RewardEditorSheet(store: _store, existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleActive(Reward reward) async {
    setState(() => _error = null);
    try {
      await _store.setActive(reward.id, !reward.active);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update reward: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _rewards;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Reward'),
      ),
      body: rewards == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                const Text(
                  'Rewards your children can spend coins on. You decide what '
                  'each one costs, and you hand it over yourself — coins have '
                  'no cash value.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                if (rewards.isEmpty)
                  const _EmptyRewards()
                else
                  ...rewards.map(
                    (reward) => _RewardCard(
                      reward: reward,
                      onEdit: () => _openEditor(existing: reward),
                      onToggleActive: () => _toggleActive(reward),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EmptyRewards extends StatelessWidget {
  const _EmptyRewards();

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
          Icon(Icons.redeem, size: 48, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            'No rewards yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Add one and it shows up on your child\'s screen straight away.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Reward reward;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: reward.active ? 1 : 0.55,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(
            reward.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reward.description.isNotEmpty) Text(reward.description),
              const SizedBox(height: 4),
              Text(
                reward.active
                    ? '${reward.coinCost} coins'
                    : '${reward.coinCost} coins · hidden from children',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: reward.active ? Colors.green.shade800 : Colors.black54,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: reward.active ? 'Retire' : 'Restore',
                icon: Icon(
                  reward.active ? Icons.visibility_off_outlined : Icons.undo,
                ),
                onPressed: onToggleActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create/edit form. Returns true when something was saved.
class _RewardEditorSheet extends StatefulWidget {
  const _RewardEditorSheet({required this.store, this.existing});

  final RewardStore store;
  final Reward? existing;

  @override
  State<_RewardEditorSheet> createState() => _RewardEditorSheetState();
}

class _RewardEditorSheetState extends State<_RewardEditorSheet> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _costController = TextEditingController(
    text: widget.existing?.coinCost.toString() ?? '',
  );

  String? _error;
  bool _saving = false;

  /// Drops a stale error once the parent starts fixing the field it was about
  /// — leaving it under a now-valid form reads as if the save failed again.
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });

    // Parsed here rather than trusted to the keyboard type: a number field
    // still accepts an empty string, and on some keyboards a stray separator.
    final cost = int.tryParse(_costController.text.trim());
    if (cost == null) {
      setState(() {
        _error = 'Enter the cost in whole coins.';
        _saving = false;
      });
      return;
    }

    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.store.create(
          title: _titleController.text,
          coinCost: cost,
          description: _descriptionController.text,
        );
      } else {
        await widget.store.update(
          existing.id,
          title: _titleController.text,
          coinCost: cost,
          description: _descriptionController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on RewardValidationError catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the soft keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'New Reward' : 'Edit Reward',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Reward',
                  hintText: 'Trip for ice cream',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText: 'Saturday afternoon',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Cost to redeem',
                  suffixText: 'coins',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Reward'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
