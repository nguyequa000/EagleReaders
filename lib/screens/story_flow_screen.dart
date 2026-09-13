import 'package:flutter/material.dart';
import 'ai_story_screen.dart';
import 'story_character_screen.dart';
import 'story_mood_screen.dart';
import 'story_setting_screen.dart';
import 'story_summary_screen.dart';
import 'story/story_config.dart';
import 'story/story_finished_screen.dart';

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

  /// Turning the last page of a finished story.
  ///
  /// Pushed on top of the reader rather than replacing it, so the back control
  /// on the finished screen returns to the story — a child who taps the arrow
  /// by accident is not stranded.
  void _openFinishedScreen(BuildContext readerContext) {
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
              MaterialPageRoute<void>(
                builder: (_) => const StoryFlowScreen(),
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
                  onNextPage: () => _openFinishedScreen(readerContext),
                ),
              ),
            );
            widget.onComplete?.call(config);
          },
        );
      default:
        throw StateError('story flow has no step $_step');
    }
  }
}
