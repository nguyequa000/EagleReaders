import 'package:flutter/material.dart';

import 'paper_background.dart';
import 'story_sprout_bubble.dart';
import 'story_theme_controller.dart';
import 'story_theme.dart';

/// Shared chrome for every step of the story flow: the header band, an
/// optional Sprout prompt, a section label, a body slot, an optional footer
/// action, and the step progress bar.
///
/// The header carries the child identity — the same yellow the child dashboard
/// uses, since building a story is something the child does — and is cut off
/// from the page with the flow's ink line, so the whole screen reads as one
/// drawn sheet rather than a coloured bar above an app.
class StoryScaffold extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;

  /// Sprout's line above the content, or null to omit the bubble entirely.
  ///
  /// The hero builder and the steps that follow it put a preview box in this
  /// space instead — on a small phone there is not room for both, and the
  /// preview is the thing the child is actually reacting to.
  final String? prompt;

  /// Small caps label above the content, or null when the screen supplies its
  /// own headings.
  ///
  /// The hero builder has three stacked control rows with different labels, so
  /// a single label owned by the scaffold would necessarily sit in the wrong
  /// place — above the preview box rather than above the options it names.
  final String? sectionLabel;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  const StoryScaffold({
    super.key,
    required this.step,
    this.prompt,
    this.sectionLabel,
    required this.child,
    this.footer,
    this.onBack,
    this.totalSteps = 4,
    this.title = "Let's Build Something!",
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);

    return Scaffold(
      backgroundColor: palette.ground,
      body: PaperBackground(
        child: Column(
          children: <Widget>[
            _buildHeader(context, palette),
            Expanded(child: _buildScrollingContent(palette)),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: footer,
              ),
            _buildProgress(palette),
          ],
        ),
      ),
    );
  }

  /// The prompt-plus-content region between the header and the footer.
  ///
  /// This scrolls rather than clips. A clipping body is not merely ugly here:
  /// [StoryOptionGrid] builds lazily, so on a 375x667 or 360x640 phone with a
  /// real status-bar inset the second row of tiles was never built at all —
  /// unreachable by touch *and* by any accessibility action, with no scroll
  /// affordance to hint that anything was missing.
  ///
  /// The footer sits outside this region, pinned above the progress bar, so the
  /// primary action never scrolls out of a child's reach. Note that the obvious
  /// `ConstrainedBox(minHeight:) + IntrinsicHeight` idiom cannot be used here:
  /// intrinsic queries throw on any viewport descendant, and the option grid is
  /// one.
  Widget _buildScrollingContent(StoryPalette palette) {
    return SingleChildScrollView(
      child: Padding(
        // The bottom inset is not cosmetic: every sticker on the page carries
        // a hard shadow offset down and right, and with no room under the last
        // row the viewport edge cut straight through it.
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (prompt != null) ...<Widget>[
              StorySproutBubble(message: prompt!, accent: palette.action),
              const SizedBox(height: 18),
            ],
            if (sectionLabel != null) ...<Widget>[
              Text(
                sectionLabel!,
                textAlign: TextAlign.center,
                style: StoryTheme.display(
                  size: 12,
                  color: palette.inkMuted,
                  weight: 700,
                  tracking: 1.6,
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StoryPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(
          bottom: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 11,
        left: 14,
        right: 16,
      ),
      child: Row(
        children: <Widget>[
          _BackSticker(
            palette: palette,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: StoryTheme.display(
                  size: 21,
                  color: palette.headerInk,
                  weight: 700,
                  tracking: 0.2,
                ),
              ),
            ),
          ),
          // Sits where the spacer that balanced the back sticker used to, so
          // the title stays optically centred.
          _ThemeSticker(palette: palette),
        ],
      ),
    );
  }

  /// Chunky beads rather than a hairline bar.
  ///
  /// Four fat segments say "four things to do" to a child who cannot yet read
  /// the label above them, and a 6px rule would have been the one un-drawn
  /// element left on the page.
  Widget _buildProgress(StoryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
      child: Column(
        children: <Widget>[
          Text(
            'STEP $step OF $totalSteps',
            style: StoryTheme.display(
              size: 12,
              color: palette.inkMuted,
              weight: 700,
              tracking: 1.6,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: List<Widget>.generate(totalSteps, (i) {
              final done = i < step;
              return Expanded(
                child: Container(
                  height: 11,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 7 : 0),
                  decoration: BoxDecoration(
                    color: done ? palette.action : palette.track,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: palette.outline,
                      width: StoryTheme.outlineWidthThin,
                    ),
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

/// The back control, drawn as a round sticker so it belongs to the same world
/// as everything else on the page.
class _BackSticker extends StatelessWidget {
  final StoryPalette palette;
  final VoidCallback onTap;

  const _BackSticker({required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      // A 42px sticker inside a 48px target: the drawn circle stays chunky
      // without dropping the hit area below the 48dp minimum.
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
          boxShadow: palette.cardShadow(depth: 3),
        ),
        child: Icon(Icons.arrow_back, color: palette.ink, size: 21),
      ),
    );
  }
}

/// Switches between day, night and following the device.
///
/// In the header because that is the one piece of chrome on every step, and
/// because a child who finds it will use it — the two palettes are a matched
/// pair, so there is no state this can leave a screen in that is broken.
class _ThemeSticker extends StatelessWidget {
  final StoryPalette palette;

  const _ThemeSticker({required this.palette});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: storyThemeController,
      builder: (context, mode, _) {
        return IconButton(
          onPressed: storyThemeController.next,
          tooltip: storyThemeController.label,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          padding: EdgeInsets.zero,
          icon: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.outline,
                width: StoryTheme.outlineWidth,
              ),
              boxShadow: palette.cardShadow(depth: 3),
            ),
            child: Icon(
              storyThemeController.icon,
              color: palette.ink,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
