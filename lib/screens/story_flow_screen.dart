import 'dart:async';

import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/coin_service.dart';
import 'ai_story_screen.dart';
import 'coins_earned_snack_bar.dart';
import 'story_character_screen.dart';
import 'story_mood_screen.dart';
import 'story_setting_screen.dart';
import 'story_summary_screen.dart';

class StoryFlowScreen extends StatefulWidget {
  final void Function(StoryConfig config)? onComplete;

  /// The child creating the story. When set, finishing the flow records a
  /// `story_created` event so it counts on the parent dashboard.
  final String? childId;

  const StoryFlowScreen({super.key, this.onComplete, this.childId});

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  int _step = 1;
  StoryConfig _config = const StoryConfig();

  void _goToStep(int step, StoryConfig config) {
    setState(() {
      _step = step;
      _config = config;
    });
  }

  /// A parent-readable name for the story, e.g. "Dragon in Space".
  static String _storyTitle(StoryConfig config) {
    final character = config.character;
    final setting = config.setting;
    if (character == null) return setting ?? 'A new story';
    return setting == null ? character : '$character in $setting';
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

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 1:
        return StoryCharacterScreen(
          onBack: () => Navigator.of(context).maybePop(),
          onNext: (config) => _goToStep(2, config),
        );
      case 2:
        return StoryMoodScreen(
          config: _config,
          onBack: () => _goToStep(1, _config),
          onNext: (config) => _goToStep(3, config),
        );
      case 3:
        return StorySettingScreen(
          config: _config,
          onBack: () => _goToStep(2, _config),
          onNext: (config) => _goToStep(4, config),
        );
      case 4:
        return StorySummaryScreen(
          config: _config,
          onBack: () => _goToStep(3, _config),
          onStartReading: (config) {
            final childId = widget.childId;
            if (childId != null) {
              unawaited(
                ActivityService.instance.logEvent(childId, 'story_created', {
                  'title': _storyTitle(config),
                }),
              );
              unawaited(_awardCoins(childId, _storyTitle(config)));
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoryReaderScreen(config: config),
              ),
            );
            widget.onComplete?.call(config);
          },
        );
      default:
        return StoryCharacterScreen(onNext: (config) => _goToStep(2, config));
    }
  }
}
