import 'package:flutter/material.dart';
import 'story_character_screen.dart';
import 'story_mood_screen.dart';
import 'story_setting_screen.dart';
import 'story_summary_screen.dart';

class StoryFlowScreen extends StatefulWidget {
  final void Function(StoryConfig config)? onComplete;

  const StoryFlowScreen({super.key, this.onComplete});

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
          onStartReading: widget.onComplete,
        );
      default:
        return StoryCharacterScreen(
          onNext: (config) => _goToStep(2, config),
        );
    }
  }
}
