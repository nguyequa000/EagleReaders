import 'package:flutter/material.dart';

import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

/// The story an Advanced writer wrote, shown back to them as a finished page.
///
/// Separate from `StoryReaderScreen`, which writes its story with the AI and
/// stays the Beginning writer's reader.
class MyStoryScreen extends StatelessWidget {
  final String title;
  final String text;

  /// "The End" — the flow opens the what-next screen. Without one, it just
  /// closes this page.
  final VoidCallback? onFinish;

  const MyStoryScreen({
    super.key,
    required this.title,
    required this.text,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        title: Text(
          'My Story',
          style: StoryTheme.display(
            size: 21,
            color: palette.headerInk,
            weight: 700,
          ),
        ),
        backgroundColor: palette.header,
        foregroundColor: palette.headerInk,
        elevation: 0,
        // The same cut the step scaffold puts under its header.
        shape: Border(
          bottom: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      // The button sits in bottomNavigationBar because the Scaffold shows
      // snack bars above it: the coin toast that arrives with this page
      // would otherwise cover "The End" for its first few seconds.
      bottomNavigationBar: ColoredBox(
        color: palette.ground,
        child: SafeArea(
          // min: StoryButton centres its label, so unconstrained it would
          // stretch the bar to the whole screen.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: StoryButton(
                  label: 'The End',
                  accent: palette.action,
                  onPressed: onFinish ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: PaperBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidth,
              ),
              boxShadow: palette.cardShadow(depth: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: StoryTheme.display(
                    size: 24,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  text,
                  style: StoryTheme.body(
                    size: 19,
                    color: palette.ink,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
