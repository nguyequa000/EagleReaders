import 'package:flutter/material.dart';

import 'story_sprout_bubble.dart';
import 'story_theme.dart';

/// Shared chrome for every step of the story flow: brand header, Sprout prompt,
/// section label, a body slot, an optional footer action, and the step progress
/// bar tinted with this step's accent.
class StoryScaffold extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String prompt;
  final String sectionLabel;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  const StoryScaffold({
    super.key,
    required this.step,
    required this.prompt,
    required this.sectionLabel,
    required this.child,
    this.footer,
    this.onBack,
    this.totalSteps = 4,
    this.title = "Let's Build Something!",
  });

  Color get _accent => StoryTheme.accentForStep(step);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoryTheme.ground,
      body: Column(
        children: <Widget>[
          _buildHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  StorySproutBubble(message: prompt, accent: _accent),
                  const SizedBox(height: 18),
                  Text(
                    sectionLabel,
                    textAlign: TextAlign.center,
                    style: StoryTheme.display(
                      size: 12,
                      color: StoryTheme.inkMuted,
                      weight: 600,
                      tracking: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: child),
                  if (footer != null) ...<Widget>[
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
          _buildProgress(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: StoryTheme.brand,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 4,
        right: 16,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: StoryTheme.display(
                size: 19,
                color: Colors.white,
                weight: 600,
                tracking: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      color: StoryTheme.brand,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: <Widget>[
          Text(
            'STEP $step OF $totalSteps',
            style: StoryTheme.display(
              size: 12,
              color: Colors.white,
              weight: 600,
              tracking: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(totalSteps, (i) {
              final done = i < step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: done
                        ? _accent
                        : Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
