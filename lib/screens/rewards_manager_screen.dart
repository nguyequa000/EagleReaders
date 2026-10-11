import 'package:flutter/material.dart';

import '../services/rewards_store.dart';
import 'live_refresh.dart';
import 'sticker_kit.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

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
    final palette = StoryTheme.of(context);
    final rewards = _rewards;

    return StickerPage(
      title: 'Rewards',
      forParent: true,
      body: rewards == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Room at the bottom so the last card clears the button.
              padding: const EdgeInsets.fromLTRB(18, 18, 22, 28),
              children: [
                Text(
                  'Rewards your children can spend coins on. You decide what '
                  'each one costs, and you hand it over yourself — coins have '
                  'no cash value.',
                  style: StoryTheme.body(color: palette.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                StoryButton(
                  label: 'New Reward',
                  accent: palette.action,
                  showArrow: false,
                  onPressed: () => _openEditor(),
                ),
                const SizedBox(height: 22),
                if (_error != null) ...[
                  StickerErrorNote(_error!),
                  const SizedBox(height: 16),
                ],
                if (rewards.isEmpty)
                  const _EmptyRewards()
                else
                  for (final (i, reward) in rewards.indexed)
                    _RewardCard(
                      index: i,
                      reward: reward,
                      onEdit: () => _openEditor(existing: reward),
                      onToggleActive: () => _toggleActive(reward),
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
    final palette = StoryTheme.of(context);
    return StickerCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          StickerIconDisc(
            icon: Icons.redeem,
            color: palette.tintMagenta,
            size: 64,
          ),
          const SizedBox(height: 14),
          Text(
            'No rewards yet',
            style: StoryTheme.display(
              size: 18,
              color: palette.ink,
              weight: 700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add one and it shows up on your child\'s screen straight away.',
            textAlign: TextAlign.center,
            style: StoryTheme.body(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.index,
    required this.reward,
    required this.onEdit,
    required this.onToggleActive,
  });

  /// Position in the list, which picks the gift's tint.
  final int index;
  final Reward reward;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StickerCard(
        // A retired reward sits flat on the page, as the children no longer
        // see it.
        color: reward.active ? palette.surface : palette.ground,
        radius: StoryTheme.radiusButton,
        depth: reward.active ? 3 : 0,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            StickerIconDisc(
              icon: Icons.redeem,
              color: reward.active
                  ? palette.tintForIndex(index + 1)
                  : palette.disabled,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: StoryTheme.display(
                      size: 17,
                      color: palette.ink,
                      weight: 700,
                    ),
                  ),
                  if (reward.description.isNotEmpty)
                    Text(
                      reward.description,
                      style: StoryTheme.body(size: 13, color: palette.inkMuted),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    reward.active
                        ? '${reward.coinCost} coins'
                        : '${reward.coinCost} coins · hidden from children',
                    style: StoryTheme.body(
                      size: 13,
                      color: reward.active ? palette.ink : palette.inkMuted,
                      weight: 700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit_outlined, color: palette.ink),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: reward.active ? 'Retire' : 'Restore',
              icon: Icon(
                reward.active ? Icons.visibility_off_outlined : Icons.undo,
                color: palette.ink,
              ),
              onPressed: onToggleActive,
            ),
          ],
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
    final palette = StoryTheme.of(context);
    return Padding(
      // Lifts the sheet above the soft keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'New Reward' : 'Edit Reward',
                style: StoryTheme.display(
                  size: 22,
                  color: palette.ink,
                  weight: 700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _clearError(),
                style: StoryTheme.body(color: palette.ink),
                decoration: stickerInputDecoration(
                  palette,
                  label: 'Reward',
                  hint: 'Trip for ice cream',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                style: StoryTheme.body(color: palette.ink),
                decoration: stickerInputDecoration(
                  palette,
                  label: 'Details (optional)',
                  hint: 'Saturday afternoon',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearError(),
                style: StoryTheme.body(color: palette.ink),
                decoration: stickerInputDecoration(
                  palette,
                  label: 'Cost to redeem (coins)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                StickerErrorNote(_error!),
              ],
              const SizedBox(height: 20),
              StoryButton(
                label: _saving ? 'Saving...' : 'Save Reward',
                accent: palette.action,
                showArrow: false,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
