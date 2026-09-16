import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'hero_catalog.dart';
import 'hero_config.dart';
import 'story_theme.dart';

/// The row of feature buttons — Face, Hair, Hat, Outfit, Pet.
class HeroFeatureRow extends StatelessWidget {
  final HeroFeature selected;
  final ValueChanged<HeroFeature> onSelect;
  final Color accent;

  const HeroFeatureRow({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (final feature in HeroFeature.values)
          _FeatureButton(
            feature: feature,
            selected: feature == selected,
            accent: accent,
            onTap: () => onSelect(feature),
          ),
      ],
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final HeroFeature feature;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.feature,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  static const Map<HeroFeature, IconData> _icons = <HeroFeature, IconData>{
    HeroFeature.avatar: Icons.face_retouching_natural,
    HeroFeature.hair: Icons.content_cut,
    HeroFeature.hat: Icons.emoji_events,
    HeroFeature.outfit: Icons.checkroom,
    HeroFeature.pet: Icons.pets,
  };

  @override
  Widget build(BuildContext context) {
    final label = HeroCatalog.labelFor(feature);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? accent : StoryTheme.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : StoryTheme.shadow,
                  width: selected ? StoryTheme.ringWidth : 1,
                ),
                boxShadow: StoryTheme.hardShadow(),
              ),
              child: Icon(
                _icons[feature],
                size: 24,
                color: selected ? Colors.white : StoryTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: StoryTheme.display(
                size: 12,
                color: selected ? accent : StoryTheme.inkMuted,
                weight: selected ? 600 : 500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The horizontally scrolling strip of options for the active feature.
///
/// Each tile previews the option on the child's own hero rather than showing a
/// generic swatch, so picking a hat means looking at that hat on that head.
class HeroOptionStrip extends StatefulWidget {
  final HeroFeature feature;
  final HeroConfig hero;
  final ValueChanged<String?> onSelect;
  final Color accent;

  const HeroOptionStrip({
    super.key,
    required this.feature,
    required this.hero,
    required this.onSelect,
    required this.accent,
  });

  @override
  State<HeroOptionStrip> createState() => _HeroOptionStripState();
}

class _HeroOptionStripState extends State<HeroOptionStrip> {
  final ScrollController _controller = ScrollController();

  /// One tile plus its gap. Paging by three keeps a tile of overlap, so the
  /// child can see that the strip moved rather than wondering if it reset.
  static const double _tile = 86;
  static const double _page = _tile * 3;

  @override
  void didUpdateWidget(HeroOptionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching feature swaps the whole list. Without this the new strip opens
    // scrolled to wherever the previous one happened to be — often past its
    // own end, showing blank space.
    if (oldWidget.feature != widget.feature && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nudge(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta)
        .clamp(0.0, _controller.position.maxScrollExtent);
    // jumpTo, not animateTo: the SRS rules out animation, and an instant move
    // is also the more legible one for a child watching the row.
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final options = HeroCatalog.optionsFor(widget.feature);
    final selected = widget.hero.selectedValue(widget.feature);

    return Row(
      children: <Widget>[
        _StripArrow(
          icon: Icons.chevron_left,
          label: 'Scroll back',
          accent: widget.accent,
          onTap: () => _nudge(-_page),
        ),
        Expanded(
          child: SizedBox(
            height: 96,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                return _OptionTile(
                  option: option,
                  feature: widget.feature,
                  hero: widget.hero,
                  selected: option.value == selected,
                  accent: widget.accent,
                  onTap: () => widget.onSelect(option.value),
                );
              },
            ),
          ),
        ),
        _StripArrow(
          icon: Icons.chevron_right,
          label: 'Scroll forward',
          accent: widget.accent,
          onTap: () => _nudge(_page),
        ),
      ],
    );
  }
}

/// A scroll control flanking the strip.
///
/// Horizontal scrolling is not a gesture a four-year-old reliably discovers,
/// and the wireframe asks for these explicitly.
class _StripArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _StripArrow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 96,
          child: Icon(icon, size: 26, color: accent),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final HeroOption option;
  final HeroFeature feature;
  final HeroConfig hero;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.feature,
    required this.hero,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  Widget _buildThumb() {
    if (option.value == null) {
      return Icon(Icons.block, size: 30, color: StoryTheme.disabled);
    }
    if (feature == HeroFeature.pet) {
      return Image.asset(option.value!, width: 48, height: 48);
    }
    // Render the option onto this child's hero, so the tile answers "what
    // would this look like on me" rather than "what does this look like".
    return SvgPicture.string(
      hero.withOption(feature, option.value).toSvg(size: 120),
      width: 58,
      height: 58,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    accent.withValues(alpha: 0.12), StoryTheme.card)
                : StoryTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : StoryTheme.shadow,
              width: selected ? StoryTheme.ringWidth : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 58, child: Center(child: _buildThumb())),
              if (feature != HeroFeature.avatar) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StoryTheme.display(
                    size: 10,
                    color: selected ? accent : StoryTheme.inkMuted,
                    weight: selected ? 600 : 500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The colour swatches for the active feature.
class HeroColorRow extends StatelessWidget {
  final HeroFeature feature;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Color accent;

  const HeroColorRow({
    super.key,
    required this.feature,
    required this.selected,
    required this.onSelect,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HeroCatalog.colorsFor(feature);
    if (colors.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: colors.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final hex = colors[index];
          final isSelected = hex.toLowerCase() == selected?.toLowerCase();
          return Semantics(
            button: true,
            selected: isSelected,
            label: '${HeroCatalog.labelFor(feature)} colour ${index + 1}',
            excludeSemantics: true,
            onTap: () => onSelect(hex),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(hex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _parseHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accent : StoryTheme.shadow,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('ff$cleaned', radix: 16));
  }
}
