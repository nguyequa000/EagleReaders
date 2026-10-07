import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/story_generator.dart';

import 'story/hero_preview.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_option.dart';
import 'story/story_row_label.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 4 of 4 — name the hero, review the choices, start reading.
///
/// The preview here is the whole story in one picture: the hero the child
/// built, standing in the place they chose, wearing the face their mood
/// called for. It is the payoff for the three steps before it, so it gets the
/// most room on the screen.
class StorySummaryScreen extends StatefulWidget {
  final StoryConfig config;
  final VoidCallback? onBack;

  /// Jump back to step 1 to change the hero.
  final VoidCallback? onEditHero;

  final void Function(StoryConfig config)? onStartReading;

  /// Every change to the story idea, so the flow can keep it across Back.
  final ValueChanged<String>? onIdeaChanged;

  const StorySummaryScreen({
    super.key,
    required this.config,
    this.onBack,
    this.onEditHero,
    this.onStartReading,
    this.onIdeaChanged,
  });

  @override
  State<StorySummaryScreen> createState() => _StorySummaryScreenState();
}

class _StorySummaryScreenState extends State<StorySummaryScreen> {
  static const int _step = 4;

  late final TextEditingController _name = TextEditingController(
    text: widget.config.hero.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// What the child wants the story to be about, for the AI to build on.
  late String _idea = widget.config.idea;

  /// The config as it stands, including whatever has been typed.
  StoryConfig get _current {
    final typed = _name.text.trim();
    return widget.config.copyWith(
      hero: widget.config.hero.copyWith(name: typed.isEmpty ? null : typed),
      idea: _idea,
    );
  }

  /// Both the name and the idea go to the story writer, so neither may carry
  /// unkind words.
  bool get _blocked => hasBadWords(_name.text) || hasBadWords(_idea);

  /// The idea lives in a sheet rather than on the page: every step has to fit
  /// without scrolling (see story_no_scroll_test), and this one is full.
  Future<void> _editIdea() async {
    final idea = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IdeaSheet(initial: _idea),
    );
    if (idea == null || !mounted) return;
    setState(() => _idea = idea);
    widget.onIdeaChanged?.call(idea);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return StoryScaffold(
      step: _step,
      title: 'Your story!',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Start Reading!',
        accent: palette.action,
        showArrow: false,
        onPressed: _blocked
            ? null
            : () => widget.onStartReading?.call(_current),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              HeroPreview(
                hero: _current.hero,
                height: HeroPreview.heightFor(
                  context,
                  fraction: 0.32,
                  min: 200,
                  max: 310,
                ),
                setting: widget.config.setting,
                mood: widget.config.mood,
              ),
              if (widget.onEditHero != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _EditHeroChip(
                    accent: palette.action,
                    onTap: widget.onEditHero!,
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: _EditHeroChip(
                  accent: palette.action,
                  onTap: _editIdea,
                  label: _idea.isEmpty ? 'Add an idea' : 'Edit idea',
                  icon: Icons.lightbulb_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const StoryRowLabel(text: 'NAME YOUR HERO'),
          const SizedBox(height: 8),
          _NameField(controller: _name, onChanged: () => setState(() {})),
          if (_blocked)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                badWordsMessage,
                style: StoryTheme.body(size: 14, color: palette.ink),
              ),
            ),
          const SizedBox(height: 16),
          const StoryRowLabel(text: 'YOUR STORY'),
          const SizedBox(height: 8),
          _SummaryRow(
            caption: 'Place',
            option: StoryOptions.byLabel(
              StoryOptions.settings,
              widget.config.setting,
            ),
            tint: palette.tintForIndex(1),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            caption: 'Feeling',
            option: StoryOptions.byLabel(
              StoryOptions.moods,
              widget.config.mood,
            ),
            tint: palette.tintForIndex(0),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Where the child types their hero's name.
///
/// Optional on purpose — a hero with no name still reads fine, and a required
/// field would block a four-year-old who cannot spell yet from their story.
class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
        boxShadow: palette.cardShadow(depth: 3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          Icon(Icons.edit_outlined, size: 18, color: palette.action),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              style: StoryTheme.display(
                size: 16,
                color: palette.ink,
                weight: 600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Give them a name',
                hintStyle: StoryTheme.body(size: 15, color: palette.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditHeroChip extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _EditHeroChip({
    required this.accent,
    required this.onTap,
    this.label = 'Edit hero',
    this.icon = Icons.tune,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            // Filled rather than outlined: the accent on a paper fill is
            // about 2:1, far under the minimum, and this chip sits over a
            // painted scene where a pale fill would disappear entirely.
            color: accent,
            borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
            border: Border.all(
              color: palette.outline,
              width: StoryTheme.outlineWidthThin,
            ),
            boxShadow: palette.cardShadow(depth: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: palette.onAction),
              const SizedBox(width: 6),
              Text(
                label,
                style: StoryTheme.display(
                  size: 13,
                  color: palette.onAction,
                  weight: 700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the child types what they want their story to be about. Pops with
/// the trimmed idea (empty to clear it), or null if dismissed.
class _IdeaSheet extends StatefulWidget {
  final String initial;

  const _IdeaSheet({required this.initial});

  @override
  State<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends State<_IdeaSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final unkind = hasBadWords(_text.text);

    return Padding(
      // Stay above the keyboard.
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const StoryRowLabel(text: 'YOUR STORY IDEA'),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: maxIdeaLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: StoryTheme.body(size: 16, color: palette.ink),
            decoration: InputDecoration(
              hintText: 'A fox finds a map to a hidden treehouse...',
              errorText: unkind ? badWordsMessage : null,
              filled: true,
              fillColor: palette.surface,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          StoryButton(
            label: 'Use this idea',
            accent: palette.action,
            showArrow: false,
            onPressed: unkind
                ? null
                : () => Navigator.pop(context, _text.text.trim()),
          ),
        ],
      ),
    );
  }
}

/// One reviewed choice. Renders the illustration for the option the child
/// actually picked; falls back to an em dash when nothing was chosen.
class _SummaryRow extends StatelessWidget {
  final String caption;
  final StoryOption? option;

  /// The tint this choice wore on its own step, carried through so the four
  /// screens read as one flow.
  final Color tint;

  const _SummaryRow({
    required this.caption,
    required this.option,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final selected = option;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidthThin,
        ),
        boxShadow: palette.cardShadow(depth: 3),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            height: 34,
            child: selected == null
                ? null
                : SvgPicture.asset(selected.asset, width: 34, height: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              caption,
              style: StoryTheme.body(
                size: 14,
                color: palette.inkMuted,
                weight: 600,
              ),
            ),
          ),
          Text(
            selected?.label ?? '—',
            style: StoryTheme.display(
              size: 15,
              color: palette.ink,
              weight: 600,
            ),
          ),
        ],
      ),
    );
  }
}
