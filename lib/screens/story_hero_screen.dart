import 'package:flutter/material.dart';

import 'story/hero_catalog.dart';
import 'story/hero_config.dart';
import 'story/hero_controls.dart';
import 'story/hero_preview.dart';
import 'story/story_button.dart';
import 'story/story_scaffold.dart';
import 'story/story_theme.dart';

/// Step 1 of 4 — build your hero.
///
/// Reads top to bottom as one thought: here is your hero, here is the part you
/// are changing, here are the choices, here are the colours. The scaffold's own
/// section label is deliberately left unset — it renders above the whole body,
/// which would put a row's label above the preview box rather than above the
/// options it actually names.
///
/// There is no expression row: the hero's face is decided by the story's mood
/// in step 2, not chosen here.
class StoryHeroScreen extends StatefulWidget {
  final HeroConfig hero;
  final VoidCallback? onBack;
  final void Function(HeroConfig hero)? onNext;

  const StoryHeroScreen({
    super.key,
    this.hero = const HeroConfig(),
    this.onBack,
    this.onNext,
  });

  @override
  State<StoryHeroScreen> createState() => _StoryHeroScreenState();
}

class _StoryHeroScreenState extends State<StoryHeroScreen> {
  static const int _step = 1;

  late HeroConfig _hero = widget.hero;
  HeroFeature _feature = HeroFeature.avatar;

  void _update(HeroConfig hero) => setState(() => _hero = hero);

  @override
  Widget build(BuildContext context) {
    final accent = StoryTheme.accentForStep(_step);
    final colors = HeroCatalog.colorsFor(_feature);

    return StoryScaffold(
      step: _step,
      title: 'Build your hero!',
      onBack: widget.onBack,
      footer: StoryButton(
        label: 'Next',
        accent: accent,
        // Always enabled: a seeded hero is already a complete character, so
        // there is no unfinished state to gate on.
        onPressed: () => widget.onNext?.call(_hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              HeroPreview(hero: _hero, height: 244),
              // Sits on the preview rather than between the preview and the
              // controls, where it broke the rhythm of the three rows and read
              // as a fourth control.
              Positioned(
                top: 10,
                right: 10,
                child: _SurpriseButton(
                  accent: accent,
                  onTap: () => _update(_hero.randomized()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          HeroFeatureRow(
            selected: _feature,
            accent: accent,
            onSelect: (feature) => setState(() => _feature = feature),
          ),
          const SizedBox(height: 18),
          _RowLabel(text: _labelForStrip()),
          const SizedBox(height: 8),
          HeroOptionStrip(
            feature: _feature,
            hero: _hero,
            accent: accent,
            onSelect: (value) => _update(_hero.withOption(_feature, value)),
          ),
          if (colors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _RowLabel(text: _labelForColors()),
            const SizedBox(height: 8),
            HeroColorRow(
              feature: _feature,
              selected: _hero.selectedColor(_feature),
              accent: accent,
              onSelect: (hex) => _update(_hero.withColor(_feature, hex)),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _labelForStrip() {
    switch (_feature) {
      case HeroFeature.avatar:
        return 'PICK YOUR HERO';
      case HeroFeature.hair:
        return 'PICK A HAIRSTYLE';
      case HeroFeature.hat:
        return 'PICK A HAT';
      case HeroFeature.outfit:
        return 'PICK AN OUTFIT';
      case HeroFeature.pet:
        return 'PICK A PET';
    }
  }

  String _labelForColors() {
    switch (_feature) {
      case HeroFeature.avatar:
        return 'SKIN TONE';
      case HeroFeature.hair:
        return 'HAIR COLOUR';
      case HeroFeature.hat:
        return 'HAT COLOUR';
      case HeroFeature.outfit:
        return 'OUTFIT COLOUR';
      case HeroFeature.pet:
        return '';
    }
  }
}

class _RowLabel extends StatelessWidget {
  final String text;

  const _RowLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: StoryTheme.display(
        size: 12,
        color: StoryTheme.inkMuted,
        weight: 600,
        tracking: 1.4,
      ),
    );
  }
}

class _SurpriseButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _SurpriseButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Surprise me',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: StoryTheme.card,
            borderRadius: BorderRadius.circular(StoryTheme.radiusButton),
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.casino, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Surprise me!',
                style:
                    StoryTheme.display(size: 13, color: accent, weight: 600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
