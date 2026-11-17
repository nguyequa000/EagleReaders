import { MaterialIcons } from '@expo/vector-icons';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type KeyboardTypeOptions,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useNav, useRoute } from '../nav/Navigator';
import { useTheme, usePalette } from '../theme/ThemeProvider';
import {
  body,
  cardShadow,
  depth as defaultDepth,
  display,
  outlineWidth,
  outlineWidthThin,
  radiusButton,
  radiusTile,
  ringWidth,
  type StoryPalette,
} from '../theme/palette';
import { PaperBackground } from './PaperBackground';

/**
 * The sticker-book pieces every screen draws with, ported from
 * lib/screens/sticker_kit.dart and the story flow's own primitives.
 */

export type IconName = React.ComponentProps<typeof MaterialIcons>['name'];

export function Icon({
  name,
  size = 22,
  color,
}: {
  name: IconName;
  size?: number;
  color: string;
}) {
  return <MaterialIcons name={name} size={size} color={color} />;
}

/**
 * A shape cut out with the ink line and sitting on a hard shadow, optionally
 * pressable. Pressing slides it into its shadow's place.
 */
export function StickerCard({
  children,
  color,
  onPress,
  radius = radiusTile,
  padding = 0,
  depth = defaultDepth,
  selected,
  style,
  innerStyle,
  accessibilityLabel,
}: {
  children: React.ReactNode;
  color?: string;
  onPress?: () => void;
  radius?: number;
  padding?: ViewStyle['padding'] | ViewStyle;
  depth?: number;
  selected?: boolean;
  style?: StyleProp<ViewStyle>;
  innerStyle?: StyleProp<ViewStyle>;
  accessibilityLabel?: string;
}) {
  const palette = usePalette();
  const [held, setHeld] = useState(false);
  const down = held && !!onPress;
  const pad = typeof padding === 'object' ? padding : { padding };

  let card = (
    <View
      style={[
        {
          backgroundColor: color ?? palette.surface,
          borderRadius: radius,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          ...cardShadow(palette, { pressed: down, depth }),
        },
        selected == null && style,
      ]}
    >
      <View style={[{ borderRadius: radius - outlineWidth, overflow: 'hidden' }, pad, innerStyle]}>
        {children}
      </View>
    </View>
  );

  if (selected != null) {
    card = (
      <View
        style={[
          {
            padding: 3,
            borderRadius: radius + 5,
            borderWidth: ringWidth,
            borderColor: selected ? palette.action : 'transparent',
          },
          style,
        ]}
      >
        {card}
      </View>
    );
  }

  const moved = (
    <View style={{ transform: [{ translateX: down ? depth : 0 }, { translateY: down ? depth : 0 }] }}>
      {card}
    </View>
  );

  if (!onPress) return moved;
  return (
    <Pressable
      onPress={onPress}
      onPressIn={() => setHeld(true)}
      onPressOut={() => setHeld(false)}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={selected != null ? { selected } : undefined}
    >
      {moved}
    </Pressable>
  );
}

/** A round sticker with an icon on it: 42px drawn inside a 48px target. */
export function StickerIconButton({
  icon,
  onPress,
  label,
  color,
}: {
  icon: IconName;
  onPress?: () => void;
  label?: string;
  color?: string;
}) {
  const palette = usePalette();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={label}
      hitSlop={3}
      style={{ width: 48, height: 48, alignItems: 'center', justifyContent: 'center' }}
    >
      <View
        style={[
          styles.circle42,
          {
            backgroundColor: color ?? palette.surface,
            borderColor: palette.outline,
            ...cardShadow(palette, { depth: 3 }),
          },
        ]}
      >
        <Icon name={icon} size={21} color={palette.ink} />
      </View>
    </Pressable>
  );
}

/** Switches between day, night and following the device. */
export function ThemeSticker() {
  const { icon, label, next } = useTheme();
  return <StickerIconButton icon={icon} label={label} onPress={next} />;
}

/**
 * The band across the top of a sticker-book screen, cut off from the page with
 * the ink line. Yellow on the child's screens, pink on the grown-ups'.
 */
export function StickerHeader({
  title,
  showBack = false,
  onBack,
  trailing,
  forParent = false,
  centerTitle,
}: {
  title: string;
  showBack?: boolean;
  onBack?: () => void;
  trailing?: React.ReactNode;
  forParent?: boolean;
  centerTitle?: boolean;
}) {
  const palette = usePalette();
  const nav = useNav();
  const insets = useSafeAreaInsets();
  const centered = centerTitle ?? showBack;
  return (
    <View
      style={{
        backgroundColor: forParent ? palette.headerParent : palette.header,
        borderBottomWidth: outlineWidth,
        borderBottomColor: palette.outline,
        paddingTop: insets.top + 10,
        paddingBottom: 11,
        paddingLeft: showBack ? 14 : 20,
        paddingRight: 16,
        flexDirection: 'row',
        alignItems: 'center',
        zIndex: 2,
      }}
    >
      {showBack && <StickerIconButton icon="arrow-back" label="Back" onPress={onBack ?? (() => nav.pop())} />}
      <View style={{ flex: 1, paddingHorizontal: showBack ? 8 : 0 }}>
        <Text
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.6}
          style={[
            display(21, forParent ? palette.headerParentInk : palette.headerInk, 700, 0.2),
            { textAlign: centered ? 'center' : 'left' },
          ]}
        >
          {title}
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>{trailing}</View>
    </View>
  );
}

/** A small rounded tag with the ink line: the coin balance, "Skip", a section title. */
export function StickerPill({
  children,
  onPress,
  color,
}: {
  children: React.ReactNode;
  onPress?: () => void;
  color?: string;
}) {
  const palette = usePalette();
  const pill = (
    <View
      style={{
        paddingHorizontal: 12,
        paddingVertical: 5,
        backgroundColor: color ?? palette.surface,
        borderRadius: 20,
        borderWidth: outlineWidthThin,
        borderColor: palette.outline,
        ...cardShadow(palette, { depth: 3 }),
      }}
    >
      {children}
    </View>
  );
  if (!onPress) return pill;
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      style={{ minHeight: 48, justifyContent: 'center', paddingHorizontal: 4 }}
    >
      {pill}
    </Pressable>
  );
}

/** A text field drawn as a paper sticker: ink edge, action-coloured when focused. */
export function StickerTextField({
  value,
  onChangeText,
  placeholder,
  label,
  icon,
  secure,
  keyboardType,
  maxLength,
  error,
  autoFocus,
  autoCapitalize,
  multiline,
  minHeight,
  onSubmit,
  textStyle,
  shadow = true,
  center,
  editable = true,
}: {
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  label?: string;
  icon?: IconName;
  secure?: boolean;
  keyboardType?: KeyboardTypeOptions;
  maxLength?: number;
  error?: string | null;
  autoFocus?: boolean;
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  multiline?: boolean;
  minHeight?: number;
  onSubmit?: () => void;
  textStyle?: StyleProp<TextStyle>;
  shadow?: boolean;
  center?: boolean;
  editable?: boolean;
}) {
  const palette = usePalette();
  const [focused, setFocused] = useState(false);
  const borderColor = error ? palette.tintCoral : focused ? palette.action : palette.outline;
  return (
    <View>
      {label ? (
        <Text style={[body(13, palette.inkMuted, 700), { marginBottom: 4, marginLeft: 4 }]}>{label}</Text>
      ) : null}
      <View
        style={{
          flexDirection: 'row',
          alignItems: multiline ? 'flex-start' : 'center',
          backgroundColor: palette.surface,
          borderRadius: radiusButton,
          borderWidth: outlineWidth,
          borderColor,
          paddingHorizontal: 12,
          minHeight: minHeight ?? 54,
          ...(shadow && !error ? cardShadow(palette, { depth: 3 }) : {}),
        }}
      >
        {icon && (
          <View style={{ marginRight: 10, paddingTop: multiline ? 14 : 0 }}>
            <Icon name={icon} size={22} color={palette.ink} />
          </View>
        )}
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={palette.inkMuted}
          secureTextEntry={secure}
          keyboardType={keyboardType}
          maxLength={maxLength}
          autoFocus={autoFocus}
          autoCapitalize={autoCapitalize ?? (secure || keyboardType === 'email-address' ? 'none' : 'sentences')}
          autoCorrect={!secure && keyboardType !== 'email-address'}
          multiline={multiline}
          editable={editable}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onSubmitEditing={onSubmit}
          returnKeyType={onSubmit && !multiline ? 'done' : undefined}
          keyboardAppearance={palette.isDark ? 'dark' : 'light'}
          style={[
            body(16, palette.ink, 400, 1.35),
            {
              flex: 1,
              paddingVertical: 14,
              textAlignVertical: multiline ? 'top' : 'center',
              textAlign: center ? 'center' : 'left',
            },
            textStyle,
          ]}
        />
      </View>
      {error ? (
        <Text style={[body(13, palette.ink, 700), { marginTop: 4, marginLeft: 4 }]}>{error}</Text>
      ) : null}
    </View>
  );
}

/** An emoji on a round tinted sticker with the ink line. */
export function StickerEmoji({
  emoji,
  color,
  size = 56,
}: {
  emoji: string;
  color: string;
  size?: number;
}) {
  const palette = usePalette();
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: color,
        borderWidth: outlineWidth,
        borderColor: palette.outline,
        alignItems: 'center',
        justifyContent: 'center',
        ...cardShadow(palette, { depth: size >= 80 ? defaultDepth : 3 }),
      }}
    >
      <Text style={{ fontSize: size * 0.48 }}>{emoji}</Text>
    </View>
  );
}

/** An icon on a round tinted sticker: the leading mark on a parent's row. */
export function StickerIconDisc({
  icon,
  color,
  size = 44,
}: {
  icon: IconName;
  color: string;
  size?: number;
}) {
  const palette = usePalette();
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: color,
        borderWidth: outlineWidthThin,
        borderColor: palette.outline,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon name={icon} size={size * 0.5} color={palette.ink} />
    </View>
  );
}

/** Primary action button: cut out with the ink line, pressing flattens it. */
export function StoryButton({
  label,
  onPress,
  showArrow = true,
  filled = true,
  style,
  small,
}: {
  label: string;
  onPress?: (() => void) | null;
  showArrow?: boolean;
  filled?: boolean;
  style?: StyleProp<ViewStyle>;
  small?: boolean;
}) {
  const palette = usePalette();
  const [held, setHeld] = useState(false);
  const enabled = !!onPress;
  const down = held && enabled;
  const labelColor = !enabled ? palette.inkMuted : filled ? palette.onAction : palette.ink;
  const fill = !enabled ? palette.disabled : filled ? palette.action : palette.surface;
  return (
    <Pressable
      onPress={onPress ?? undefined}
      disabled={!enabled}
      onPressIn={() => setHeld(true)}
      onPressOut={() => setHeld(false)}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: !enabled }}
      style={style}
    >
      <View
        style={{
          transform: [{ translateX: down ? defaultDepth : 0 }, { translateY: down ? defaultDepth : 0 }],
          paddingVertical: small ? 10 : 15,
          paddingHorizontal: 12,
          backgroundColor: fill,
          borderRadius: radiusButton,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          ...cardShadow(palette, { pressed: down }),
        }}
      >
        <Text
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.6}
          style={[display(small ? 16 : 18, labelColor, 700, 0.3), { flexShrink: 1, textAlign: 'center' }]}
        >
          {label}
        </Text>
        {showArrow && (
          <View style={{ marginLeft: 9 }}>
            <Icon name="arrow-forward" size={20} color={labelColor} />
          </View>
        )}
      </View>
    </Pressable>
  );
}

/** Sprout's speech bubble: the 🌱 avatar and a paper bubble. */
export function SproutBubble({ message }: { message: string }) {
  const palette = usePalette();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
      <View
        style={{
          width: 48,
          height: 48,
          borderRadius: 24,
          backgroundColor: palette.surface,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          alignItems: 'center',
          justifyContent: 'center',
          ...cardShadow(palette, { depth: 3 }),
        }}
      >
        <Text style={{ fontSize: 24 }}>🌱</Text>
      </View>
      <View
        style={{
          flex: 1,
          marginLeft: 12,
          padding: 14,
          backgroundColor: palette.surface,
          borderTopLeftRadius: 4,
          borderTopRightRadius: radiusTile,
          borderBottomLeftRadius: radiusTile,
          borderBottomRightRadius: radiusTile,
          borderWidth: outlineWidthThin,
          borderColor: palette.outline,
          ...cardShadow(palette, { depth: 3 }),
        }}
      >
        <Text style={body(15, palette.ink, 500)}>{message}</Text>
      </View>
    </View>
  );
}

/** The small caps label that names the row of choices beneath it. */
export function RowLabel({ text, align = 'center' }: { text: string; align?: 'center' | 'left' }) {
  const palette = usePalette();
  return (
    <Text style={[display(12, palette.inkMuted, 700, 1.6), { textAlign: align }]}>
      {text.toUpperCase()}
    </Text>
  );
}

/** The bold title over a group of cards: "Reading Stats", "Child Profiles". */
export function SectionTitle({ text }: { text: string }) {
  const palette = usePalette();
  return <Text style={[display(19, palette.ink, 700), { marginBottom: 10 }]}>{text}</Text>;
}

/** Something went wrong, said on a coral card rather than in red text. */
export function ErrorNote({ message, center }: { message: string; center?: boolean }) {
  const palette = usePalette();
  return (
    <StickerCard
      color={palette.tintCoral}
      radius={radiusButton}
      depth={3}
      padding={{ paddingHorizontal: 14, paddingVertical: 10 }}
    >
      <Text style={[body(15, palette.ink, 700), center && { textAlign: 'center' }]}>{message}</Text>
    </StickerCard>
  );
}

/**
 * One tappable line on a paper card: a leading mark, a title, an optional line
 * under it and an arrow.
 */
export function StickerRow({
  leading,
  title,
  subtitle,
  onPress,
  trailing,
}: {
  leading: React.ReactNode;
  title: string;
  subtitle?: string;
  onPress?: () => void;
  trailing?: React.ReactNode;
}) {
  const palette = usePalette();
  return (
    <StickerCard
      onPress={onPress}
      radius={radiusButton}
      depth={3}
      padding={{ paddingHorizontal: 14, paddingVertical: 12 }}
      accessibilityLabel={title}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        {leading}
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text style={display(17, palette.ink, 700)}>{title}</Text>
          {subtitle ? <Text style={body(13, palette.inkMuted, 400, 1.35)}>{subtitle}</Text> : null}
        </View>
        <View style={{ marginLeft: 8 }}>
          {trailing ?? (onPress ? <Icon name="chevron-right" color={palette.ink} /> : null)}
        </View>
      </View>
    </StickerCard>
  );
}

/** One choice in a list of who's who: an emoji sticker, a name and an arrow. */
export function StickerChoiceCard({
  emoji,
  label,
  tint,
  onPress,
}: {
  emoji: string;
  label: string;
  tint: string;
  onPress: () => void;
}) {
  const palette = usePalette();
  return (
    <StickerCard
      onPress={onPress}
      accessibilityLabel={label}
      padding={{ paddingHorizontal: 16, paddingVertical: 14 }}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <StickerEmoji emoji={emoji} color={tint} />
        <Text numberOfLines={1} style={[display(22, palette.ink, 700), { flex: 1, marginLeft: 16 }]}>
          {label}
        </Text>
        <Icon name="arrow-forward" size={26} color={palette.ink} />
      </View>
    </StickerCard>
  );
}

/** A whole sticker-book screen: the paper, the header band and the body. */
export function StickerPage({
  title,
  children,
  forParent = false,
  allowBack = true,
  actions,
  onBack,
}: {
  title: string;
  children: React.ReactNode;
  forParent?: boolean;
  allowBack?: boolean;
  actions?: React.ReactNode;
  onBack?: () => void;
}) {
  const route = useRoute();
  return (
    <PaperBackground>
      <StickerHeader
        title={title}
        showBack={allowBack && route.canPop}
        onBack={onBack}
        forParent={forParent}
        trailing={
          <>
            {actions}
            <ThemeSticker />
          </>
        }
      />
      <View style={{ flex: 1 }}>{children}</View>
    </PaperBackground>
  );
}

/**
 * A sticker-book screen laid out like login: the header band, then an emoji
 * on a round sticker and a prompt on a tag, with the children under them.
 */
export function StickerPromptPage({
  title,
  emoji,
  emojiTint,
  prompt,
  caption,
  children,
  allowBack = true,
  forParent = false,
}: {
  title: string;
  emoji: string;
  emojiTint: string;
  prompt: string;
  caption?: string;
  children?: React.ReactNode;
  allowBack?: boolean;
  forParent?: boolean;
}) {
  const palette = usePalette();
  const route = useRoute();
  return (
    <PaperBackground>
      <StickerHeader
        title={title}
        showBack={allowBack && route.canPop}
        forParent={forParent}
        trailing={<ThemeSticker />}
      />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: 24, paddingBottom: 28 }}
          keyboardShouldPersistTaps="handled"
        >
          <View style={{ alignItems: 'center' }}>
            <StickerEmoji emoji={emoji} color={emojiTint} size={104} />
            <View style={{ height: 20 }} />
            <PromptTag text={prompt} />
          </View>
          {caption ? (
            <Text style={[body(15, palette.inkMuted), { textAlign: 'center', marginTop: 12 }]}>{caption}</Text>
          ) : null}
          <View style={{ height: 32 }} />
          {children}
        </ScrollView>
      </KeyboardAvoidingView>
    </PaperBackground>
  );
}

/** The greeting on a straight yellow tag. */
export function PromptTag({ text, size = 24 }: { text: string; size?: number }) {
  const palette = usePalette();
  return (
    <StickerCard
      color={palette.tintYellow}
      radius={radiusButton}
      padding={{ paddingHorizontal: 20, paddingVertical: 8 }}
    >
      <Text style={[display(size, palette.ink, 700), { textAlign: 'center' }]}>{text}</Text>
    </StickerCard>
  );
}

/** A PIN screen: the prompt page with the PIN field and one button under it. */
export function StickerPinPage({
  title,
  emoji,
  emojiTint,
  prompt,
  value,
  onChangeText,
  error,
  buttonLabel,
  onSubmit,
  forParent,
}: {
  title: string;
  emoji: string;
  emojiTint: string;
  prompt: string;
  value: string;
  onChangeText: (text: string) => void;
  error?: string | null;
  buttonLabel: string;
  onSubmit: () => void;
  forParent?: boolean;
}) {
  const palette = usePalette();
  return (
    <StickerPromptPage title={title} emoji={emoji} emojiTint={emojiTint} prompt={prompt} forParent={forParent}>
      <StickerTextField
        value={value}
        onChangeText={(t) => onChangeText(t.replace(/\D/g, ''))}
        secure
        keyboardType="number-pad"
        maxLength={4}
        center
        autoFocus
        onSubmit={onSubmit}
        textStyle={display(32, palette.ink, 700, 16)}
      />
      {error ? (
        <View style={{ marginTop: 16 }}>
          <ErrorNote message={error} center />
        </View>
      ) : null}
      <View style={{ height: 24 }} />
      <StoryButton label={buttonLabel} showArrow={false} onPress={onSubmit} />
    </StickerPromptPage>
  );
}

/** A centred spinner in the action colour. */
export function Spinner({ size = 'large' }: { size?: 'small' | 'large' }) {
  const palette = usePalette();
  return <ActivityIndicator size={size} color={palette.action} />;
}

export function CenterSpinner() {
  return (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Spinner />
    </View>
  );
}

/** A paper dialog: title, content and a row of text actions. */
export function StickerDialog({
  title,
  children,
  actions,
}: {
  title?: string;
  children?: React.ReactNode;
  actions?: { label: string; onPress?: (() => void) | null; busy?: boolean }[];
}) {
  const palette = usePalette();
  return (
    <View
      style={{
        width: '100%',
        maxWidth: 420,
        backgroundColor: palette.surface,
        borderRadius: radiusTile,
        borderWidth: outlineWidth,
        borderColor: palette.outline,
        padding: 22,
      }}
    >
      {title ? <Text style={[display(20, palette.ink, 700), { marginBottom: 12 }]}>{title}</Text> : null}
      {children}
      {actions && actions.length > 0 && (
        <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 18, gap: 8 }}>
          {actions.map((a) => (
            <Pressable
              key={a.label}
              onPress={a.onPress ?? undefined}
              disabled={!a.onPress}
              style={{ paddingHorizontal: 12, paddingVertical: 8, minHeight: 40, justifyContent: 'center' }}
            >
              {a.busy ? (
                <Spinner size="small" />
              ) : (
                <Text style={display(16, a.onPress ? palette.ink : palette.inkMuted, 700)}>{a.label}</Text>
              )}
            </Pressable>
          ))}
        </View>
      )}
    </View>
  );
}

/** The paper panel a bottom sheet is drawn on. */
export function SheetPanel({ children, padded = true }: { children: React.ReactNode; padded?: boolean }) {
  const palette = usePalette();
  const insets = useSafeAreaInsets();
  return (
    <View
      style={{
        backgroundColor: palette.surface,
        borderTopLeftRadius: radiusTile,
        borderTopRightRadius: radiusTile,
        borderWidth: outlineWidth,
        borderBottomWidth: 0,
        borderColor: palette.outline,
        paddingBottom: insets.bottom + (padded ? 20 : 0),
        maxHeight: '88%',
      }}
    >
      {padded ? <View style={{ padding: 20, paddingBottom: 0 }}>{children}</View> : children}
    </View>
  );
}

/** A plain text row inside a dialog or sheet, for pickers. */
export function OptionRow({
  label,
  selected,
  onPress,
  leading,
}: {
  label: string;
  selected?: boolean;
  onPress: () => void;
  leading?: React.ReactNode;
}) {
  const palette = usePalette();
  return (
    <Pressable
      onPress={onPress}
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 13,
        paddingHorizontal: 6,
        borderRadius: 10,
        backgroundColor: selected ? palette.tintBlue : 'transparent',
      }}
    >
      {leading}
      <Text style={[body(16, palette.ink, selected ? 800 : 500), { flex: 1, marginLeft: leading ? 12 : 0 }]}>
        {label}
      </Text>
      {selected ? <Icon name="check" color={palette.ink} /> : null}
    </Pressable>
  );
}

/** A check box row: a ticked square sticker and a label. */
export function CheckRow({
  label,
  value,
  onChange,
  leading,
  subtitle,
  disabled,
}: {
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
  leading?: React.ReactNode;
  subtitle?: string;
  disabled?: boolean;
}) {
  const palette = usePalette();
  return (
    <Pressable
      onPress={() => !disabled && onChange(!value)}
      accessibilityRole="checkbox"
      accessibilityState={{ checked: value, disabled }}
      style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 10 }}
    >
      <View
        style={{
          width: 26,
          height: 26,
          borderRadius: 7,
          borderWidth: outlineWidthThin,
          borderColor: palette.outline,
          backgroundColor: value ? palette.action : 'transparent',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {value ? <Icon name="check" size={18} color={palette.onAction} /> : null}
      </View>
      {leading ? <View style={{ marginLeft: 12 }}>{leading}</View> : null}
      <View style={{ flex: 1, marginLeft: 12 }}>
        <Text style={body(16, palette.ink, 600)}>{label}</Text>
        {subtitle ? <Text style={body(13, palette.inkMuted)}>{subtitle}</Text> : null}
      </View>
    </Pressable>
  );
}

/** Chunky beads rather than a hairline bar, one per step. */
export function BeadProgress({
  label,
  total,
  done,
}: {
  label: string;
  total: number;
  done: (index: number) => boolean;
}) {
  const palette = usePalette();
  return (
    <View style={{ alignItems: 'center' }}>
      <Text style={display(12, palette.inkMuted, 700, 1.6)}>{label}</Text>
      <View style={{ flexDirection: 'row', marginTop: 7, alignSelf: 'stretch' }}>
        {Array.from({ length: total }, (_, i) => (
          <View
            key={i}
            style={{
              flex: 1,
              height: 11,
              marginRight: i < total - 1 ? 7 : 0,
              borderRadius: 7,
              borderWidth: outlineWidthThin,
              borderColor: palette.outline,
              backgroundColor: done(i) ? palette.action : palette.track,
            }}
          />
        ))}
      </View>
    </View>
  );
}

export function paletteText(palette: StoryPalette) {
  return {
    muted: body(15, palette.inkMuted),
    plain: body(15, palette.ink),
  };
}

const styles = StyleSheet.create({
  circle42: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: outlineWidth,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
