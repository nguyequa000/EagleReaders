import 'package:flutter/material.dart';

import '../services/child_profiles.dart';
import 'parent_dashboard_screen.dart';
import 'sticker_kit.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

/// Shown once, right after a parent creates their account: how many children,
/// and a name + 4-digit PIN for each. Saved to Firestore via [ChildProfileStore].
class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key, this.store});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final ChildProfileStore? store;

  static const int maxChildren = 6;

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _pinCtrls = [];
  int _count = 1;
  bool _saving = false;
  String? _error;

  static final RegExp _pinPattern = RegExp(r'^\d{4}$');

  @override
  void initState() {
    super.initState();
    _setCount(1);
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _pinCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _setCount(int n) {
    while (_nameCtrls.length < n) {
      _nameCtrls.add(TextEditingController());
      _pinCtrls.add(TextEditingController());
    }
    while (_nameCtrls.length > n) {
      _nameCtrls.removeLast().dispose();
      _pinCtrls.removeLast().dispose();
    }
    setState(() {
      _count = n;
      _error = null;
    });
  }

  Future<void> _save() async {
    final names = [for (final c in _nameCtrls) c.text.trim()];
    final pins = [for (final c in _pinCtrls) c.text];

    if (names.any((n) => n.isEmpty) ||
        pins.any((p) => !_pinPattern.hasMatch(p))) {
      setState(() => _error = 'Give each child a name and a 4-digit PIN.');
      return;
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final profiles = [
      for (var i = 0; i < names.length; i++)
        ChildProfile.withPin(id: '${now}_$i', name: names[i], pin: pins[i]),
    ];

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _store.save(profiles);
    } catch (_) {
      // Leave the form filled in so the parent can simply press Done again.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Check your connection and try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Forward the store so an injected one keeps flowing through.
        builder: (_) => ParentDashboardScreen(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerPage(
      title: 'Add Your Children',
      forParent: true,
      // Straight after registration; there is nothing to go back to.
      allowBack: false,
      // Scrollable so the dynamic rows + keyboard don't overflow (see CLAUDE.md).
      body: SingleChildScrollView(
        // Extra room right and below for the hard shadows.
        padding: const EdgeInsets.fromLTRB(20, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set up a profile and PIN for each child on this account.',
              style: StoryTheme.body(color: palette.inkMuted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'How many children?',
                  style: StoryTheme.display(
                    size: 18,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                const Spacer(),
                StickerPill(
                  child: DropdownButton<int>(
                    value: _count,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: StoryTheme.display(size: 18, color: palette.ink),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.ink,
                    onChanged: _saving
                        ? null
                        : (val) {
                            if (val != null) _setCount(val);
                          },
                    items: [
                      for (var n = 1; n <= ChildSetupScreen.maxChildren; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _count; i++) ...[
              _childCard(i),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              StickerErrorNote(_error!),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            StoryButton(
              label: _saving ? 'Saving…' : 'Done',
              accent: palette.action,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _childCard(int i) {
    final palette = StoryTheme.of(context);
    return StickerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StickerEmoji(
                emoji: '🧒',
                color: i.isEven ? palette.tintYellow : palette.tintBlue,
                size: 40,
              ),
              const SizedBox(width: 12),
              Text(
                'Child ${i + 1}',
                style: StoryTheme.display(
                  size: 18,
                  color: palette.ink,
                  weight: 700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrls[i],
            textCapitalization: TextCapitalization.words,
            style: StoryTheme.body(color: palette.ink),
            decoration: stickerInputDecoration(palette, label: 'Name'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrls[i],
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            style: StoryTheme.body(color: palette.ink),
            decoration: stickerInputDecoration(
              palette,
              label: '4-digit PIN',
              counterText: '',
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
    );
  }
}
