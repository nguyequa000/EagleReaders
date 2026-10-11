import 'package:flutter/material.dart';

import '../services/child_profiles.dart';
import '../services/family_settings.dart';
import '../services/reader_audience.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

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
    final palette = StoryTheme.of(context);
    final children = _children;
    Widget message(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: StoryTheme.body(color: palette.ink),
        ),
      ),
    );
    return StickerPage(
      title: 'Age & Time Limits',
      forParent: true,
      body: _error != null
          ? message(_error!)
          : children == null
          ? const Center(child: CircularProgressIndicator())
          : children.isEmpty
          ? message('Add a child first.')
          : ListView(
              // Extra room right and below for the hard shadows.
              padding: const EdgeInsets.fromLTRB(18, 18, 22, 28),
              children: [
                const _AgeGuide(),
                const SizedBox(height: 16),
                Text(
                  "The daily limit counts today's reading time. When it's "
                  'used up, reading and story making wait until tomorrow '
                  'unless a grown-up unlocks them with the parent PIN.',
                  style: StoryTheme.body(color: palette.inkMuted),
                ),
                const SizedBox(height: 18),
                for (final (i, child) in children.indexed) ...[
                  _childCard(child, _rules[child.id] ?? const ChildRules(), i),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  Widget _childCard(ChildProfile child, ChildRules rules, int index) {
    final palette = StoryTheme.of(context);
    final label = StoryTheme.body(color: palette.ink, weight: 700);
    final choice = StoryTheme.display(size: 16, color: palette.ink);
    return StickerCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StickerEmoji(
                emoji: child.emoji,
                color: index.isEven ? palette.tintYellow : palette.tintBlue,
                size: 42,
              ),
              const SizedBox(width: 12),
              Text(
                child.name,
                style: StoryTheme.display(
                  size: 19,
                  color: palette.ink,
                  weight: 700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Age', style: label)),
              DropdownButton<AgeBand>(
                key: Key('age-${child.id}'),
                value: rules.ageBand,
                underline: const SizedBox.shrink(),
                style: choice,
                dropdownColor: palette.surface,
                iconEnabledColor: palette.ink,
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
          // What the chosen band changes, right where it's chosen.
          Text(
            rules.ageBand.summary,
            key: Key('age-summary-${child.id}'),
            style: StoryTheme.body(size: 13, color: palette.inkMuted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text('Daily reading limit', style: label)),
              DropdownButton<int?>(
                key: Key('limit-${child.id}'),
                value: rules.dailyLimitMinutes,
                underline: const SizedBox.shrink(),
                style: choice,
                dropdownColor: palette.surface,
                iconEnabledColor: palette.ink,
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

/// What each age band means, so a parent can pick one knowingly.
class _AgeGuide extends StatelessWidget {
  const _AgeGuide();

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      color: palette.tintGreen,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What the ages mean',
            style: StoryTheme.display(
              size: 18,
              color: palette.ink,
              weight: 700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The age changes how Sprout writes stories and quiz questions '
            'for that child.',
            style: StoryTheme.body(color: palette.ink),
          ),
          for (final band in AgeBand.values) ...[
            const SizedBox(height: 10),
            Text(
              band.label,
              style: StoryTheme.body(color: palette.ink, weight: 800),
            ),
            Text(band.summary, style: StoryTheme.body(color: palette.ink)),
          ],
        ],
      ),
    );
  }
}
