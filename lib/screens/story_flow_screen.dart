import 'dart:async';

import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/coin_service.dart';
import '../services/story_store.dart';
import 'ai_story_screen.dart';
import 'coins_earned_snack_bar.dart';
import 'my_story_screen.dart';
import 'story_hero_screen.dart';
import 'story_mode_screen.dart';
import 'story_mood_screen.dart';
import 'story_setting_screen.dart';
import 'story_summary_screen.dart';
import 'story_writer_screen.dart';
import 'story/hero_catalog.dart';
import 'story/story_config.dart';
import 'story/story_finished_screen.dart';

class StoryFlowScreen extends StatefulWidget {
  final void Function(StoryConfig config)? onComplete;

  /// The child creating the story. When set, finishing the flow records a
  /// `story_created` event so it counts on the parent dashboard.
  final String? childId;

  /// Only for display (the end-of-story quiz); activity is keyed by [childId].
  final String childName;

  const StoryFlowScreen({
    super.key,
    this.onComplete,
    this.childId,
    this.childName = '',
  });

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  int _step = 1;
  StoryConfig _config = const StoryConfig();

  /// Double taps would push two readers and generate two stories.
  bool _starting = false;

  /// The Advanced writer is open on top of the chooser.
  bool _writing = false;

  void _goToStep(int step, StoryConfig config) {
    setState(() {
      _step = step;
      _config = config;
    });
  }

  /// Turning the last page of a finished story.
  ///
  /// Pushed on top of the reader rather than replacing it, so the back control
  /// on the finished screen returns to the story — a child who taps the arrow
  /// by accident is not stranded.
  ///
  /// [childId] is passed in rather than read from `widget`: this screen has
  /// already been replaced by the reader, so its state is gone by the time the
  /// last page turns.
  void _openFinishedScreen(
    BuildContext readerContext,
    String? childId,
    String childName,
  ) {
    Navigator.of(readerContext).push(
      MaterialPageRoute<void>(
        builder: (finishedContext) => StoryFinishedScreen(
          // Both exits unwind the same two routes — the finished screen and the
          // reader beneath it — so the finished story never lingers under
          // whatever comes next. Starting a second story used to only replace
          // the finished screen, which left the first story on the stack and
          // sent step 1's back button to it instead of home.
          //
          // Capture the navigator first: after the first pop, finishedContext
          // is defunct and Navigator.of would throw.
          onCreateAnother: () {
            final navigator = Navigator.of(finishedContext);
            navigator.pop();
            navigator.pop();
            navigator.push(
              // Same child, so the second story is logged and earns coins too.
              MaterialPageRoute<void>(
                builder: (_) =>
                    StoryFlowScreen(childId: childId, childName: childName),
              ),
            );
          },
          onReturnHome: () {
            final navigator = Navigator.of(finishedContext);
            navigator.pop();
            navigator.pop();
          },
        ),
      ),
    );
  }

  /// A parent-readable name for the story, e.g. "Robin in Outer Space".
  ///
  /// Reads the hero's own name when the child typed one, and the character
  /// they picked when they did not. The config no longer carries a `character`
  /// string — a hero is a whole configuration now — so this reaches through it
  /// rather than reading a field that went away.
  static String _storyTitle(StoryConfig config) {
    final named = config.hero.name?.trim();
    final who = (named == null || named.isEmpty)
        ? HeroCatalog.heroes
              .firstWhere(
                (option) => option.value == config.hero.effectiveCharacter,
                orElse: () => HeroCatalog.heroes.first,
              )
              .label
        : named;
    final setting = config.setting;
    return setting == null ? who : '$who in $setting';
  }

  /// Coins for finishing a story (CR #2). Fire-and-forget: the story opens
  /// straight away and the toast follows once the award lands.
  Future<void> _awardCoins(String childId, String title) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final coins = await CoinService.instance.awardStory(childId, title);
      if (coins > 0) messenger?.showSnackBar(coinsEarnedSnackBar(coins));
    } catch (_) {}
  }

  /// Beginning writer: Sprout writes the story from the picks. This is the
  /// flow's original ending, moved here unchanged when the chooser was added.
  void _startBeginner(StoryConfig config) {
    if (_starting) return;
    _starting = true;
    final childId = widget.childId;
    final childName = widget.childName;
    if (childId != null) {
      unawaited(
        ActivityService.instance.logEvent(childId, 'story_created', {
          'title': _storyTitle(config),
        }),
      );
      unawaited(_awardCoins(childId, _storyTitle(config)));
    }
    // pushReplacement, not push: the reader takes the flow's place in
    // the stack instead of sitting on top of it. Without this, leaving
    // the reader walked back through steps 4, 3, 2, 1 before reaching
    // the dashboard.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Bind the exits to the reader's own context. This screen's
        // context is defunct the moment pushReplacement removes it, so
        // using it here would fire callbacks against a dead element.
        builder: (readerContext) => StoryReaderScreen(
          config: config,
          childId: childId,
          childName: childName,
          onNextPage: () =>
              _openFinishedScreen(readerContext, childId, childName),
        ),
      ),
    );
    widget.onComplete?.call(config);
  }

  /// Advanced writer: the child writes the story themselves.
  ///
  /// The writer is pushed on top of the chooser, so backing out of it (which
  /// saves a draft) lands here again and Beginning is still one tap away. A
  /// finished story is logged and earns coins like a beginner one, then
  /// replaces the flow the same way the reader does.
  Future<void> _startAdvanced(StoryConfig config) async {
    if (_starting || _writing) return;
    _writing = true;
    final childId = widget.childId;
    final childName = widget.childName;
    final saved = await Navigator.of(context).push<SavedStory>(
      MaterialPageRoute(
        builder: (_) => StoryWriterScreen(config: config, childId: childId),
      ),
    );
    _writing = false;
    if (saved == null || !mounted) return;
    _starting = true;

    final typed = saved.title.trim();
    final title = (typed.isEmpty || typed == StoryDraft.defaultTitle)
        ? _storyTitle(config)
        : typed;
    if (childId != null) {
      unawaited(
        ActivityService.instance.logEvent(childId, 'story_created', {
          'title': title,
        }),
      );
      unawaited(_awardCoins(childId, title));
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (storyContext) => MyStoryScreen(
          title: saved.title,
          text: saved.text,
          onFinish: () => _openFinishedScreen(storyContext, childId, childName),
        ),
      ),
    );
    widget.onComplete?.call(config);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 1:
        return StoryHeroScreen(
          hero: _config.hero,
          onBack: () => Navigator.of(context).maybePop(),
          onNext: (hero) => _goToStep(2, _config.copyWith(hero: hero)),
        );
      case 2:
        return StorySettingScreen(
          config: _config,
          onBack: () => _goToStep(1, _config),
          onNext: (config) => _goToStep(3, config),
        );
      case 3:
        return StoryMoodScreen(
          config: _config,
          onBack: () => _goToStep(2, _config),
          onNext: (config) => _goToStep(4, config),
        );
      case 4:
        return StorySummaryScreen(
          config: _config,
          onBack: () => _goToStep(3, _config),
          // Straight back to the builder rather than three taps of Back.
          onEditHero: () => _goToStep(1, _config),
          // Kept so going back and returning doesn't lose what they typed.
          onIdeaChanged: (idea) => _config = _config.copyWith(idea: idea),
          // Writer level first; the reader opens from the chooser.
          onStartReading: (config) => _goToStep(5, config),
        );
      case 5:
        return StoryModeScreen(
          onBack: () => _goToStep(4, _config),
          onChoose: (level) => level == WriterLevel.beginning
              ? _startBeginner(_config)
              : _startAdvanced(_config),
        );
      default:
        throw StateError('story flow has no step $_step');
    }
  }
}
