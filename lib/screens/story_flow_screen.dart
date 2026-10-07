import 'package:flutter/material.dart';
import 'ai_story_screen.dart';
import 'story_character_screen.dart';
import 'story_mood_screen.dart';
import 'story_setting_screen.dart';
import 'story_summary_screen.dart';

class StoryFlowScreen extends StatefulWidget {
  final String childName;
  final void Function(StoryConfig config)? onComplete;

  const StoryFlowScreen({super.key, required this.childName, this.onComplete});

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  int _step = 1;
  StoryConfig _config = const StoryConfig();
  bool _starting = false;

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
          onNext: (config) => _goToStep(2, config.copyWith(idea: _config.idea)),
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
          onBack: (config) => _goToStep(3, config),
          onStartReading: (config) async {
            // Double taps would push two readers and generate two stories.
            if (_starting) return;
            _starting = true;
            widget.onComplete?.call(config);
            final finished = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => StoryReaderScreen(
                  config: config,
                  childName: widget.childName,
                ),
              ),
            );
            _starting = false;
            // Finished (or handed off to its quiz): leave the wizard so the
            // child lands back on the dashboard. Back mid-story keeps it.
            if (finished == true && context.mounted) {
              Navigator.of(context).removeRoute(ModalRoute.of(context)!);
            }
          },
        );
      default:
        return StoryCharacterScreen(onNext: (config) => _goToStep(2, config));
    }
  }
}
