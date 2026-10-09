import 'dart:async';

import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/coin_service.dart';
import '../services/story_store.dart';
import 'ai_story_screen.dart';
import 'coins_earned_snack_bar.dart';
import 'story/hero_catalog.dart';
import 'story/story_config.dart';

/// A parent-readable name for a story, e.g. "Robin in Outer Space".
///
/// Reads the hero's own name when the child typed one, and the character
/// they picked when they did not.
String storyTitle(StoryConfig config) {
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

/// Logs a new story for the parent dashboard and pays the story coins
/// (CR #2). Fire-and-forget: the caller moves on straight away and the coin
/// toast follows once the award lands.
void recordStoryCreated(BuildContext context, String childId, String title) {
  // Taken now: by the time the award lands this screen may be gone.
  final messenger = ScaffoldMessenger.maybeOf(context);
  unawaited(
    ActivityService.instance.logEvent(childId, 'story_created', {
      'title': title,
    }),
  );
  unawaited(() async {
    try {
      final coins = await CoinService.instance.awardStory(childId, title);
      if (coins > 0) messenger?.showSnackBar(coinsEarnedSnackBar(coins));
    } catch (_) {}
  }());
}

/// Saves a Beginning writer story as the child reads it, for the dashboard's
/// "My Stories" (finished) and "Still working on" (not yet).
///
/// Give [save] to [StoryReaderScreen.onProgress]. Saves run one after
/// another, so the first one's new id is what later ones update, and once
/// the child reaches the end the story stays finished.
class AiStorySaver {
  final String childId;
  final StoryConfig config;

  /// Defaults to [StoryStore.instance].
  final StoryStore? store;

  /// The story's document, once it has one (or the one being resumed).
  String? id;

  bool _finished = false;
  Future<void> _queue = Future.value();

  AiStorySaver({
    required this.childId,
    required this.config,
    this.id,
    this.store,
    bool finished = false,
  }) : _finished = finished;

  StoryStore get _store => store ?? StoryStore.instance;

  void save(StoryProgress progress) {
    if (progress.finished) _finished = true;
    final finished = _finished;
    _queue = _queue.then((_) => _write(progress, finished));
  }

  /// Waits for every save so far; for tests.
  Future<void> get settled => _queue;

  Future<void> _write(StoryProgress progress, bool finished) async {
    final story = progress.story;
    final text = story.pages.join('\n\n');
    try {
      id = await _store.saveAiStory(
        childId,
        {
          'title': story.title,
          'text': text,
          'pages': story.pages,
          'choices': story.choices,
          'questions': [for (final q in story.questions) q.toJson()],
          'page': progress.page,
          'chapters': progress.chapters,
          'hero': config.hero.effectiveCharacter,
          'heroName': config.hero.name,
          'mood': config.mood,
          'setting': config.setting,
          'config': storyConfigToMap(config),
          'totalWords': StoryDraft.countWords(text),
        },
        id: id,
        completed: finished,
      );
    } catch (e) {
      // A story that can't be saved still reads; it just won't be listed.
      debugPrint('Story save failed: $e');
    }
  }
}
