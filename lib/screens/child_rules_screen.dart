import 'package:flutter/material.dart';

import '../services/child_profiles.dart';
import '../services/family_settings.dart';
import '../services/reader_audience.dart';

/// Age Restrictions and Time Limit: each child's age band and daily reading
/// limit, from Parent Settings.
class ChildRulesScreen extends StatefulWidget {
  /// Defaults to a [ChildProfileStore] on the real Firebase.
  final ChildProfileStore? store;

  /// Defaults to [FamilySettings.instance].
  final FamilySettings? settings;

  const ChildRulesScreen({super.key, this.store, this.settings});

  /// The daily limits a parent can pick, in minutes; null is no limit.
  static const List<int?> limits = [15, 30, 45, 60, null];

  static String limitLabel(int? minutes) => switch (minutes) {
    null => 'No limit',
    60 => '1 hour',
    _ => '$minutes minutes',
  };

  @override
  State<ChildRulesScreen> createState() => _ChildRulesScreenState();
}

class _ChildRulesScreenState extends State<ChildRulesScreen> {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  FamilySettings get _settings => widget.settings ?? FamilySettings.instance;

  List<ChildProfile>? _children;
  final Map<String, ChildRules> _rules = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final children = await _store.load();
      for (final child in children) {
        _rules[child.id] = await _settings.loadChild(child.id);
      }
      if (mounted) setState(() => _children = children);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "We couldn't load your children. Try again.");
      }
    }
  }

  Future<void> _save(ChildProfile child, ChildRules next) async {
    final previous = _rules[child.id] ?? const ChildRules();
    setState(() => _rules[child.id] = next);
    try {
      await _settings.saveChild(child.id, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rules[child.id] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("We couldn't save ${child.name}'s settings.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Age & Time Limits'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : children == null
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
          ? const Center(child: Text('Add a child first.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Age sets how Sprout writes stories and quizzes (Spooky '
                  'stories are hidden for ages 3–5). The daily limit counts '
                  "today's reading time; when it's used up, reading and "
                  'story making wait until tomorrow unless a grown-up '
                  'unlocks them.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                for (final child in children) ...[
                  _childCard(child, _rules[child.id] ?? const ChildRules()),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _childCard(ChildProfile child, ChildRules rules) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${child.emoji} ${child.name}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Age')),
              DropdownButton<AgeBand>(
                key: Key('age-${child.id}'),
                value: rules.ageBand,
                underline: const SizedBox.shrink(),
                items: [
                  for (final band in AgeBand.values)
                    DropdownMenuItem(value: band, child: Text(band.label)),
                ],
                onChanged: (band) {
                  if (band == null) return;
                  _save(
                    child,
                    ChildRules(
                      ageBand: band,
                      dailyLimitMinutes: rules.dailyLimitMinutes,
                      limitUnlockedOn: rules.limitUnlockedOn,
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(child: Text('Daily reading limit')),
              DropdownButton<int?>(
                key: Key('limit-${child.id}'),
                value: rules.dailyLimitMinutes,
                underline: const SizedBox.shrink(),
                items: [
                  for (final minutes in ChildRulesScreen.limits)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(ChildRulesScreen.limitLabel(minutes)),
                    ),
                ],
                onChanged: (minutes) => _save(
                  child,
                  ChildRules(
                    ageBand: rules.ageBand,
                    dailyLimitMinutes: minutes,
                    limitUnlockedOn: rules.limitUnlockedOn,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
