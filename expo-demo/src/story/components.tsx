import React, { useRef, useState } from 'react';
import {
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  Text,
  useWindowDimensions,
  View,
  type ScrollViewInstance,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Circle, Defs, LinearGradient, Rect, Stop, SvgXml } from 'react-native-svg';

import { BeadProgress, Icon, SproutBubble, StickerIconButton, ThemeSticker } from '../components/sticker';
import { PaperBackground } from '../components/PaperBackground';
import { storyImages } from '../generated/storyImages';
import { storySvgs } from '../generated/storySvgs';
import { usePalette } from '../theme/ThemeProvider';
import {
  cardShadow,
  depth,
  display,
  outlineWidth,
  outlineWidthThin,
  radiusTile,
  ringWidth,
  tintForIndex,
  withAlpha,
} from '../theme/palette';
import {
  colorsFor,
  featureLabel,
  HERO_FEATURES,
  heroAsset,
  optionsFor,
  selectedValue,
  withOption,
  type HeroConfig,
  type HeroFeature,
  type StoryOption,
} from './model';
import { SceneSvg, sceneForDark, sceneForLabel, sceneForMood } from './StoryScene';

/** A bundled OpenMoji illustration. */
export function Illustration({ asset, size }: { asset: string; size: number }) {
  const xml = storySvgs[asset];
  if (!xml) return null;
  return <SvgXml xml={xml} width={size} height={size} />;
}

/** A bundled hero or pet picture. */
export function StoryImage({ asset, size }: { asset: string; size: number }) {
  const source = storyImages[asset];
  if (!source) return null;
  return <Image source={source} style={{ width: size, height: size }} resizeMode="contain" />;
}

/** The preview's height as a fraction of the screen, clamped. */
export function usePreviewHeight(fraction: number, min: number, max: number): number {
  const { height } = useWindowDimensions();
  return Math.max(min, Math.min(max, height * fraction));
}

/**
 * The big preview box across the top of every step: the hero, standing in
 * the chosen place, in the light the mood casts.
 */
export function HeroPreview({
  hero,
  height,
  setting,
  mood,
  children,
}: {
  hero: HeroConfig;
  height: number;
  setting?: string | null;
  mood?: string | null;
  children?: React.ReactNode;
}) {
  const palette = usePalette();
  const [width, setWidth] = useState(0);
  let scene = sceneForLabel(setting);
  if (scene) {
    scene = sceneForMood(scene, mood);
    if (palette.isDark) scene = sceneForDark(scene, palette.ground);
  }
  const label = [hero.name ? `Your hero, ${hero.name}` : 'Your hero', setting && `in ${setting}`, mood && `feeling ${mood}`]
    .filter(Boolean)
    .join(', ');
  const inner = Math.max(0, width - outlineWidth * 2);
  const innerHeight = height - outlineWidth * 2;
  return (
    <View
      accessible
      accessibilityLabel={label}
      onLayout={(e) => setWidth(e.nativeEvent.layout.width)}
      style={{
        height,
        borderRadius: radiusTile,
        borderWidth: outlineWidth,
        borderColor: palette.outline,
        backgroundColor: palette.surface,
        ...cardShadow(palette, { depth: 6 }),
      }}
    >
      <View style={{ flex: 1, borderRadius: radiusTile - outlineWidth, overflow: 'hidden' }}>
        {inner > 0 &&
          (scene ? (
            <SceneSvg scene={scene} width={inner} height={innerHeight} outline={palette.outline} />
          ) : (
            <EmptyBackdrop width={inner} height={innerHeight} />
          ))}
        <View
          style={{ position: 'absolute', left: 0, right: 0, bottom: height * 0.05, alignItems: 'center' }}
          pointerEvents="none"
        >
          <StoryImage asset={heroAsset(hero)} size={height * 0.86} />
        </View>
        {hero.petAsset ? (
          <View style={{ position: 'absolute', right: height * 0.06, bottom: height * 0.05 }} pointerEvents="none">
            <StoryImage asset={hero.petAsset} size={height * 0.4} />
          </View>
        ) : null}
      </View>
      {children}
    </View>
  );
}

/** The blank page of the sticker book, before a place is chosen. */
function EmptyBackdrop({ width, height }: { width: number; height: number }) {
  const palette = usePalette();
  const s = Math.min(width, height);
  const bubble = (fx: number, fy: number, fr: number, fill: string, key: string) => (
    <Circle
      key={key}
      cx={width * fx}
      cy={height * fy}
      r={s * fr}
      fill={fill}
      stroke={withAlpha(palette.outline, 0.22)}
      strokeWidth={2}
    />
  );
  return (
    <Svg width={width} height={height}>
      <Defs>
        <LinearGradient id="empty" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={palette.surface} />
          <Stop offset="1" stopColor={palette.ground} />
        </LinearGradient>
      </Defs>
      <Rect x={0} y={0} width={width} height={height} fill="url(#empty)" />
      {bubble(0.16, 0.26, 0.13, withAlpha(palette.tintYellow, 0.5), 'a')}
      {bubble(0.88, 0.2, 0.09, withAlpha(palette.tintBlue, 0.45), 'b')}
      {bubble(0.8, 0.74, 0.16, withAlpha(palette.tintMagenta, 0.4), 'c')}
    </Svg>
  );
}

/** The 2x2 option grid shared by the mood and place steps. */
export function OptionGrid({
  options,
  selected,
  onSelect,
}: {
  options: StoryOption[];
  selected?: string | null;
  onSelect: (label: string) => void;
}) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 13 }}>
      {options.map((option, i) => (
        <OptionTile
          key={option.label}
          option={option}
          tintIndex={i}
          selected={option.label === selected}
          onPress={() => onSelect(option.label)}
        />
      ))}
    </View>
  );
}

function OptionTile({
  option,
  tintIndex,
  selected,
  onPress,
}: {
  option: StoryOption;
  tintIndex: number;
  selected: boolean;
  onPress: () => void;
}) {
  const palette = usePalette();
  const [held, setHeld] = useState(false);
  return (
    <Pressable
      onPress={onPress}
      onPressIn={() => setHeld(true)}
      onPressOut={() => setHeld(false)}
      accessibilityRole="button"
      accessibilityLabel={option.label}
      accessibilityState={{ selected }}
      style={{ width: '48%' }}
    >
      <View
        style={{
          transform: [{ translateX: held ? depth : 0 }, { translateY: held ? depth : 0 }],
          padding: 3,
          borderRadius: radiusTile + 5,
          borderWidth: ringWidth,
          borderColor: selected ? palette.action : 'transparent',
        }}
      >
        <View
          style={{
            aspectRatio: 1.42,
            backgroundColor: tintForIndex(palette, tintIndex),
            borderRadius: radiusTile,
            borderWidth: outlineWidth,
            borderColor: palette.outline,
            alignItems: 'center',
            justifyContent: 'center',
            ...cardShadow(palette, { pressed: held }),
          }}
        >
          <Illustration asset={option.asset} size={52} />
          <Text style={[display(15.5, palette.ink, selected ? 700 : 600), { marginTop: 6, textAlign: 'center' }]}>
            {option.label}
          </Text>
          {selected && (
            <View
              style={{
                position: 'absolute',
                top: 7,
                right: 7,
                width: 24,
                height: 24,
                borderRadius: 12,
                backgroundColor: palette.action,
                borderWidth: outlineWidthThin,
                borderColor: palette.outline,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="check" size={13} color={palette.onAction} />
            </View>
          )}
        </View>
      </View>
    </Pressable>
  );
}

/**
 * Shared chrome for every step of the story flow: the yellow header band, an
 * optional Sprout prompt, the content (scrolls rather than clips), a footer
 * pinned above the progress beads.
 */
export function StoryScaffold({
  step,
  totalSteps = 4,
  title = "Let's Build Something!",
  prompt,
  children,
  footer,
  onBack,
  scrollRef,
}: {
  step: number;
  totalSteps?: number;
  title?: string;
  prompt?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  onBack: () => void;
  scrollRef?: React.RefObject<ScrollViewInstance | null>;
}) {
  const palette = usePalette();
  const insets = useSafeAreaInsets();
  return (
    <PaperBackground>
      <View
        style={{
          backgroundColor: palette.header,
          borderBottomWidth: outlineWidth,
          borderBottomColor: palette.outline,
          paddingTop: insets.top + 10,
          paddingBottom: 11,
          paddingLeft: 14,
          paddingRight: 16,
          flexDirection: 'row',
          alignItems: 'center',
          zIndex: 2,
        }}
      >
        <StickerIconButton icon="arrow-back" label="Back" onPress={onBack} />
        <Text
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.6}
          style={[display(21, palette.headerInk, 700, 0.2), { flex: 1, textAlign: 'center', paddingHorizontal: 8 }]}
        >
          {title}
        </Text>
        <ThemeSticker />
      </View>
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          ref={scrollRef}
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12 }}
          keyboardShouldPersistTaps="handled"
        >
          {prompt ? (
            <View style={{ marginBottom: 18 }}>
              <SproutBubble message={prompt} />
            </View>
          ) : null}
          {children}
        </ScrollView>
        {footer ? <View style={{ paddingHorizontal: 20, paddingTop: 12, paddingBottom: 10 }}>{footer}</View> : null}
        <View style={{ paddingHorizontal: 20, paddingTop: 2, paddingBottom: insets.bottom + 12 }}>
          <BeadProgress label={`STEP ${step} OF ${totalSteps}`} total={totalSteps} done={(i) => i < step} />
        </View>
      </KeyboardAvoidingView>
    </PaperBackground>
  );
}

const FEATURE_ICONS: Record<HeroFeature, 'face-retouching-natural' | 'directions-run' | 'pets'> = {
  hero: 'face-retouching-natural',
  pose: 'directions-run',
  pet: 'pets',
};

/** The row of feature buttons: Hero, Pose, Pet. */
export function HeroFeatureRow({
  selected,
  onSelect,
}: {
  selected: HeroFeature;
  onSelect: (feature: HeroFeature) => void;
}) {
  const palette = usePalette();
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-around' }}>
      {HERO_FEATURES.map((feature, i) => {
        const on = feature === selected;
        return (
          <Pressable
            key={feature}
            onPress={() => onSelect(feature)}
            accessibilityRole="button"
            accessibilityLabel={featureLabel(feature)}
            accessibilityState={{ selected: on }}
            style={{ alignItems: 'center' }}
          >
            <View
              style={{
                width: 52,
                height: 52,
                borderRadius: 26,
                backgroundColor: on ? palette.action : tintForIndex(palette, i),
                borderWidth: outlineWidth,
                borderColor: palette.outline,
                alignItems: 'center',
                justifyContent: 'center',
                ...cardShadow(palette, { depth: 3, pressed: on }),
              }}
            >
              <Icon name={FEATURE_ICONS[feature]} size={24} color={on ? palette.onAction : palette.ink} />
            </View>
            <Text style={[display(12, on ? palette.action : palette.inkMuted, on ? 600 : 500), { marginTop: 6 }]}>
              {featureLabel(feature)}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/**
 * The scrolling strip of options for the active feature. Each tile previews
 * the option on the child's own hero.
 */
export function HeroOptionStrip({
  feature,
  hero,
  onSelect,
}: {
  feature: HeroFeature;
  hero: HeroConfig;
  onSelect: (value: string | null) => void;
}) {
  const palette = usePalette();
  const scroll = useRef<ScrollViewInstance>(null);
  const offset = useRef(0);
  const options = optionsFor(feature);
  const selected = selectedValue(hero, feature);
  const page = 86 * 3;
  const nudge = (delta: number) => {
    offset.current = Math.max(0, offset.current + delta);
    scroll.current?.scrollTo({ x: offset.current, animated: false });
  };
  React.useEffect(() => {
    offset.current = 0;
    scroll.current?.scrollTo({ x: 0, animated: false });
  }, [feature]);

  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      <Pressable onPress={() => nudge(-page)} accessibilityLabel="Scroll back" style={{ width: 28, height: 96, justifyContent: 'center' }}>
        <Icon name="chevron-left" size={26} color={palette.action} />
      </Pressable>
      <ScrollView
        ref={scroll}
        horizontal
        showsHorizontalScrollIndicator={false}
        onScroll={(e) => (offset.current = e.nativeEvent.contentOffset.x)}
        scrollEventThrottle={32}
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingHorizontal: 2, paddingVertical: 4, gap: 10 }}
      >
        {options.map((option) => {
          const on = option.value === selected;
          return (
            <Pressable
              key={option.value ?? 'none'}
              onPress={() => onSelect(option.value)}
              accessibilityRole="button"
              accessibilityLabel={option.label}
              accessibilityState={{ selected: on }}
            >
              <View
                style={{
                  width: 76,
                  height: 88,
                  padding: 6,
                  backgroundColor: palette.surface,
                  borderRadius: 16,
                  borderWidth: on ? ringWidth : outlineWidthThin,
                  borderColor: on ? palette.action : palette.outline,
                  alignItems: 'center',
                  justifyContent: 'center',
                  ...cardShadow(palette, { depth: 3, pressed: on }),
                }}
              >
                <View style={{ height: 58, justifyContent: 'center' }}>
                  {option.value == null ? (
                    <Icon name="block" size={30} color={palette.disabled} />
                  ) : feature === 'pet' ? (
                    <StoryImage asset={option.value} size={48} />
                  ) : (
                    <StoryImage asset={heroAsset(withOption(hero, feature, option.value))} size={58} />
                  )}
                </View>
                {feature !== 'hero' && (
                  <Text numberOfLines={1} style={[display(10, on ? palette.action : palette.inkMuted, on ? 600 : 500), { marginTop: 2 }]}>
                    {option.label}
                  </Text>
                )}
              </View>
            </Pressable>
          );
        })}
      </ScrollView>
      <Pressable onPress={() => nudge(page)} accessibilityLabel="Scroll forward" style={{ width: 28, height: 96, justifyContent: 'center', alignItems: 'flex-end' }}>
        <Icon name="chevron-right" size={26} color={palette.action} />
      </Pressable>
    </View>
  );
}

/** The outfit colour swatches. */
export function HeroColorRow({
  feature,
  selected,
  onSelect,
}: {
  feature: HeroFeature;
  selected?: string | null;
  onSelect: (hex: string) => void;
}) {
  const palette = usePalette();
  const colors = colorsFor(feature);
  if (colors.length === 0) return null;
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', gap: 9 }}>
      {colors.map((hex, index) => {
        const on = hex.toLowerCase() === selected?.toLowerCase();
        return (
          <Pressable
            key={hex}
            onPress={() => onSelect(hex)}
            accessibilityRole="button"
            accessibilityLabel={`${featureLabel(feature)} colour ${index + 1}`}
            accessibilityState={{ selected: on }}
          >
            <View
              style={{
                width: 36,
                height: 36,
                borderRadius: 18,
                backgroundColor: hex,
                borderWidth: on ? 4 : outlineWidthThin,
                borderColor: on ? palette.action : palette.outline,
                ...cardShadow(palette, { depth: 2, pressed: on }),
              }}
            />
          </Pressable>
        );
      })}
    </View>
  );
}

/** A filled action chip that sits over the preview: "Edit hero", "Add an idea". */
export function PreviewChip({
  label,
  icon,
  onPress,
}: {
  label: string;
  icon: React.ComponentProps<typeof Icon>['name'];
  onPress: () => void;
}) {
  const palette = usePalette();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label}>
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: 12,
          paddingVertical: 7,
          backgroundColor: palette.action,
          borderRadius: 16,
          borderWidth: outlineWidthThin,
          borderColor: palette.outline,
          ...cardShadow(palette, { depth: 3 }),
        }}
      >
        <Icon name={icon} size={15} color={palette.onAction} />
        <Text style={[display(13, palette.onAction, 700), { marginLeft: 6 }]}>{label}</Text>
      </View>
    </Pressable>
  );
}
