import 'package:flutter/material.dart';

import 'child_pin_screen.dart';
import '../services/child_profiles.dart';
import 'live_refresh.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

class ChildSelectorScreen extends StatefulWidget {
  const ChildSelectorScreen({super.key, this.store});

  /// Injectable for tests; defaults to the shared Firebase singletons.
  final ChildProfileStore? store;

  @override
  State<ChildSelectorScreen> createState() => _ChildSelectorScreenState();
}

class _ChildSelectorScreenState extends State<ChildSelectorScreen>
    with LiveRefresh {
  late final ChildProfileStore _store = widget.store ?? ChildProfileStore();
  List<ChildProfile>? _children;

  @override
  void initState() {
    super.initState();
    _load();
    // A child added on another device appears without leaving this screen.
    refreshOn(() => [_store.changes()], _load);
  }

  Future<void> _load() async {
    List<ChildProfile> children;
    try {
      children = await _store.load();
    } catch (_) {
      // Offline or rules-denied: fall back to the empty state rather than
      // leaving the spinner up forever.
      children = [];
    }
    if (mounted) setState(() => _children = children);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final children = _children;
    if (children != null && children.isEmpty) {
      return StickerPromptPage(
        title: 'Who are you?',
        emoji: '🌱',
        emojiTint: palette.tintGreen,
        prompt: 'No child profiles yet.',
        caption: 'Ask a parent to add them.',
      );
    }
    return StickerPromptPage(
      title: 'Who are you?',
      emoji: '👋',
      emojiTint: palette.tintBlue,
      prompt: 'Pick your name!',
      children: [
        if (children == null)
          Center(child: CircularProgressIndicator(color: palette.action))
        else
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 20),
            StickerChoiceCard(
              index: i,
              emoji: child.emoji,
              label: child.name,
              // Each child their own colour, the same each time.
              tint: palette.tintForIndex(i + 1),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChildPinScreen(child: child)),
              ),
            ),
          ],
      ],
    );
  }
}
