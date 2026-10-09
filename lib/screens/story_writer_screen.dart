import 'package:flutter/material.dart';

import '../services/sprout_prompts.dart';
import '../services/story_generator.dart';
import '../services/story_store.dart';
import 'story/hero_catalog.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_scaffold.dart';
import 'story/story_sprout_bubble.dart';
import 'story/story_theme.dart';

/// What Sprout is told when the child asks for an idea: their three picks and
/// the part of the story. Never anything typed — not the story, the title,
/// the hero's name or the summary's idea (TC-AI-SAFE-004/005).
SproutRequest sproutRequestFor(StoryConfig config, StoryStage stage) =>
    SproutRequest(
      character: config.hero.effectiveCharacter,
      setting: config.setting,
      mood: config.mood,
      stage: stage,
    );

/// Advanced writer mode: the child writes the story, Sprout only asks
/// questions when they tap for an idea.
///
/// Pops with a [SavedStory] when the child finishes, or with null when they
/// go back (after quietly saving a draft). The flow decides what comes next.
class StoryWriterScreen extends StatefulWidget {
  final StoryConfig config;

  /// Whose story this is. Without one (the dev entry point) nothing is saved,
  /// but finishing still hands the story back.
  final String? childId;

  /// Defaults to the offline [LocalSproutIdeas] bank; tests pass a fake.
  final SproutIdeaSource? ideas;

  /// Defaults to [StoryStore.instance].
  final StoryStore? store;

  /// False hides "Need an idea?" and "Ask Sprout" (Parent Settings → AI
  /// Settings → Sprout's writing ideas).
  final bool showIdeas;

  const StoryWriterScreen({
    super.key,
    required this.config,
    this.childId,
    this.ideas,
    this.store,
    this.showIdeas = true,
  });

  @override
  State<StoryWriterScreen> createState() => _StoryWriterScreenState();
}

enum _WriteMode { free, guided }

class _StoryWriterScreenState extends State<StoryWriterScreen> {
  static const _parts = [
    StoryStage.beginning,
    StoryStage.middle,
    StoryStage.end,
  ];
  static const _partNames = {
    StoryStage.beginning: 'Beginning',
    StoryStage.middle: 'Middle',
    StoryStage.end: 'End',
  };

  late final SproutIdeaSource _ideas = widget.ideas ?? LocalSproutIdeas();
  StoryStore get _store => widget.store ?? StoryStore.instance;

  final _title = TextEditingController();
  final _free = TextEditingController();
  final Map<StoryStage, TextEditingController> _guided = {
    for (final stage in _parts) stage: TextEditingController(),
  };

  // TODO(team): confirm. Both modes keep their own text while the screen is
  // open, and whichever mode is showing at "I'm done!" is the one saved.
  _WriteMode _mode = _WriteMode.free;

  /// Sprout's current question per stage (free mode uses `any`). Shown as
  /// plain text only — nothing ever copies it into a field (TC-AI-SAFE-006).
  final Map<StoryStage, String> _sprout = {};
  final _freeSproutKey = GlobalKey();
  int _ideasShown = 0;

  String? _draftId;
  bool _saving = false;
  bool _leaving = false;

  @override
  void dispose() {
    _title.dispose();
    _free.dispose();
    for (final controller in _guided.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _heroLabel => HeroCatalog.heroes
      .firstWhere(
        (h) => h.value == widget.config.hero.effectiveCharacter,
        orElse: () => HeroCatalog.heroes.first,
      )
      .label;

  StoryDraft _draftFor(_WriteMode mode) {
    final config = widget.config;
    final name = config.hero.name?.trim();
    final heroName = (name == null || name.isEmpty) ? null : name;
    return mode == _WriteMode.free
        ? StoryDraft.free(
            title: _title.text,
            text: _free.text,
            hero: config.hero.effectiveCharacter,
            heroName: heroName,
            mood: config.mood,
            setting: config.setting,
            ideasShown: _ideasShown,
          )
        : StoryDraft.guided(
            title: _title.text,
            beginning: _guided[StoryStage.beginning]!.text,
            middle: _guided[StoryStage.middle]!.text,
            end: _guided[StoryStage.end]!.text,
            hero: config.hero.effectiveCharacter,
            heroName: heroName,
            mood: config.mood,
            setting: config.setting,
            ideasShown: _ideasShown,
          );
  }

  StoryDraft get _draft => _draftFor(_mode);

  int get _partsWritten =>
      _guided.values.where((c) => c.text.trim().isNotEmpty).length;

  bool get _unkind {
    final visible = _mode == _WriteMode.free
        ? [_free.text]
        : [for (final c in _guided.values) c.text];
    return [_title.text, ...visible].any(hasBadWords);
  }

  bool get _canFinish => _draft.text.isNotEmpty && !_unkind && !_saving;

  void _askSprout(StoryStage stage) {
    final idea = _ideas.nextIdea(sproutRequestFor(widget.config, stage));
    setState(() {
      _sprout[stage] = idea;
      _ideasShown++;
    });
    if (stage == StoryStage.any) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _freeSproutKey.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  Future<void> _finish() async {
    final draft = _draft;
    final childId = widget.childId;
    if (childId == null) {
      Navigator.of(
        context,
      ).pop(SavedStory(id: '', title: draft.effectiveTitle, text: draft.text));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _store.complete(childId, draft, id: _draftId);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      debugPrint('Story save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("We couldn't save your story. Try again!"),
        ),
      );
    }
  }

  /// Back: keep what they wrote as a draft, without a dialog in the way.
  Future<void> _leave() async {
    if (_leaving || _saving) return;
    _leaving = true;
    final childId = widget.childId;
    final other = _mode == _WriteMode.free
        ? _WriteMode.guided
        : _WriteMode.free;
    final draft = _draft.isEmpty ? _draftFor(other) : _draft;
    if (childId != null && !draft.isEmpty) {
      try {
        _draftId = await _store.saveDraft(childId, draft, id: _draftId);
      } catch (e) {
        debugPrint('Story draft save failed: $e');
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: StoryScaffold(
        step: 4,
        title: 'My Story',
        onBack: _leave,
        footer: _buildFooter(palette),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildPicks(palette),
            const SizedBox(height: 14),
            _buildModeToggle(palette),
            const SizedBox(height: 14),
            _WritingField(
              key: const Key('story-title'),
              controller: _title,
              hint: 'Name your story',
              maxLength: 60,
              fontSize: 20,
              bold: true,
              onChanged: _changed,
            ),
            const SizedBox(height: 14),
            if (_mode == _WriteMode.free)
              ..._buildFree(palette)
            else
              ..._buildGuided(palette),
            if (_unkind)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  badWordsMessage,
                  style: StoryTheme.body(size: 15, color: palette.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _changed() => setState(() {});

  Widget _buildPicks(StoryPalette palette) {
    final name = widget.config.hero.name?.trim();
    final picks = <String>[
      (name == null || name.isEmpty) ? _heroLabel : name,
      ?widget.config.setting,
      ?widget.config.mood,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < picks.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.tintForIndex(i + 1),
              borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidthThin,
              ),
            ),
            child: Text(
              picks[i],
              style: StoryTheme.display(
                size: 14,
                color: palette.ink,
                weight: 600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModeToggle(StoryPalette palette) {
    Widget option(String label, _WriteMode mode) => Expanded(
      child: Semantics(
        selected: _mode == mode,
        child: StoryButton(
          label: label,
          accent: palette.action,
          showArrow: false,
          filled: _mode == mode,
          onPressed: () {
            // The focused box may be the one this switch removes; without
            // this the keyboard jumps to the title and covers the new boxes.
            FocusScope.of(context).unfocus();
            setState(() => _mode = mode);
          },
        ),
      ),
    );
    return Row(
      children: <Widget>[
        option('Free write', _WriteMode.free),
        const SizedBox(width: 10),
        option('Beginning · Middle · End', _WriteMode.guided),
      ],
    );
  }

  List<Widget> _buildFree(StoryPalette palette) {
    final idea = _sprout[StoryStage.any];
    return <Widget>[
      _WritingField(
        key: const Key('story-free'),
        controller: _free,
        hint: 'Once upon a time…',
        maxLength: 2000,
        minLines: 8,
        onChanged: _changed,
      ),
      const SizedBox(height: 6),
      Text(
        '${StoryDraft.countWords(_free.text)} words',
        textAlign: TextAlign.right,
        style: StoryTheme.body(size: 14, color: palette.inkMuted),
      ),
      if (idea != null) ...<Widget>[
        const SizedBox(height: 10),
        Column(
          key: _freeSproutKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StorySproutBubble(
              message: 'Sprout wonders… $idea',
              accent: palette.action,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: StoryButton(
                    label: 'Another idea',
                    accent: palette.action,
                    showArrow: false,
                    filled: false,
                    onPressed: () => _askSprout(StoryStage.any),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StoryButton(
                    label: 'Got it',
                    accent: palette.action,
                    showArrow: false,
                    filled: false,
                    onPressed: () =>
                        setState(() => _sprout.remove(StoryStage.any)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildGuided(StoryPalette palette) {
    return <Widget>[
      for (var i = 0; i < _parts.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: 14),
        _PartCard(
          number: i + 1,
          heading: _partNames[_parts[i]]!,
          hint: stageHint(
            _parts[i],
            LocalSproutIdeas.characterPhrase(
              widget.config.hero.effectiveCharacter,
            ),
          ),
          tint: palette.tintForIndex(i),
          controller: _guided[_parts[i]]!,
          idea: _sprout[_parts[i]],
          onAskSprout: widget.showIdeas ? () => _askSprout(_parts[i]) : null,
          onChanged: _changed,
        ),
      ],
    ];
  }

  Widget _buildFooter(StoryPalette palette) {
    final done = StoryButton(
      label: _saving ? 'Saving…' : "I'm done!",
      accent: palette.action,
      showArrow: false,
      onPressed: _canFinish ? _finish : null,
    );
    if (!widget.showIdeas && _mode == _WriteMode.free) return done;
    if (_mode == _WriteMode.guided) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$_partsWritten of 3 parts written',
            textAlign: TextAlign.center,
            style: StoryTheme.body(size: 15, color: palette.ink, weight: 600),
          ),
          const SizedBox(height: 8),
          done,
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: StoryButton(
            label: 'Need an idea?',
            accent: palette.action,
            showArrow: false,
            filled: false,
            onPressed: () => _askSprout(StoryStage.any),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: done),
      ],
    );
  }
}

/// A text box drawn like the summary's name field: paper fill, ink outline.
class _WritingField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final double fontSize;
  final bool bold;
  final VoidCallback onChanged;

  const _WritingField({
    super.key,
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.onChanged,
    this.minLines = 1,
    this.fontSize = 18,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final multiline = minLines > 1;

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
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        maxLength: maxLength,
        minLines: minLines,
        maxLines: multiline ? null : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textCapitalization: multiline
            ? TextCapitalization.sentences
            : TextCapitalization.words,
        style: StoryTheme.body(
          size: fontSize,
          color: palette.ink,
          weight: bold ? 700 : 400,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: hint,
          hintStyle: StoryTheme.body(size: fontSize, color: palette.inkMuted),
        ),
      ),
    );
  }
}

/// One part of a guided story: badge, heading, hint, Ask Sprout, and a box.
class _PartCard extends StatelessWidget {
  final int number;
  final String heading;
  final String hint;
  final Color tint;
  final TextEditingController controller;
  final String? idea;

  /// Null hides the Ask Sprout chip.
  final VoidCallback? onAskSprout;
  final VoidCallback onChanged;

  const _PartCard({
    required this.number,
    required this.heading,
    required this.hint,
    required this.tint,
    required this.controller,
    required this.idea,
    required this.onAskSprout,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final written = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidthThin,
        ),
        boxShadow: palette.cardShadow(depth: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                label: written ? '$heading written' : 'Part $number',
                excludeSemantics: true,
                child: Container(
                  key: Key('badge-$number'),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: written ? palette.action : palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.outline,
                      width: StoryTheme.outlineWidthThin,
                    ),
                  ),
                  child: Center(
                    child: written
                        ? Icon(Icons.check, size: 20, color: palette.onAction)
                        : Text(
                            '$number',
                            style: StoryTheme.display(
                              size: 16,
                              color: palette.ink,
                              weight: 700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  heading,
                  style: StoryTheme.display(
                    size: 19,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
              ),
              if (onAskSprout != null) _AskSproutChip(onTap: onAskSprout!),
            ],
          ),
          const SizedBox(height: 6),
          Text(hint, style: StoryTheme.body(size: 15, color: palette.ink)),
          if (idea != null) ...<Widget>[
            const SizedBox(height: 10),
            StorySproutBubble(message: idea!, accent: palette.action),
          ],
          const SizedBox(height: 10),
          _WritingField(
            key: Key('story-${heading.toLowerCase()}'),
            controller: controller,
            hint: 'Write the ${heading.toLowerCase()} here…',
            maxLength: 600,
            minLines: 3,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AskSproutChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AskSproutChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Semantics(
      button: true,
      label: 'Ask Sprout',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.action,
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
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: palette.onAction,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ask Sprout',
                    style: StoryTheme.display(
                      size: 14,
                      color: palette.onAction,
                      weight: 700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
