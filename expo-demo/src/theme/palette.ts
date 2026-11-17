import type { TextStyle, ViewStyle } from 'react-native';

/**
 * The colours of one theme mode, matching lib/screens/story/story_theme.dart.
 *
 * The story flow is drawn as a sticker book: pastel shapes edged with a soft
 * tinted line and pressed onto a sheet of paper. The two modes are a matched
 * pair: every role exists in both.
 */
export type StoryPalette = {
  isDark: boolean;
  ground: string;
  surface: string;
  header: string;
  headerInk: string;
  headerParent: string;
  headerParentInk: string;
  ink: string;
  inkMuted: string;
  outline: string;
  shadowInk: string;
  paperFleck: string;
  line: string;
  action: string;
  onAction: string;
  disabled: string;
  track: string;
  tintBlue: string;
  tintCoral: string;
  tintMagenta: string;
  tintYellow: string;
  tintGreen: string;
};

export const lightPalette: StoryPalette = {
  isDark: false,
  ground: '#FFFDF5',
  surface: '#FFFFFF',
  header: '#FFEDB7',
  headerInk: '#3B2A35',
  headerParent: '#FFDBEE',
  headerParentInk: '#3B2A35',
  ink: '#3B2A35',
  inkMuted: '#6D5F68',
  outline: '#FFBEE1',
  shadowInk: '#E9D9E3',
  paperFleck: '#F6DCE9',
  line: '#FFDBEE',
  action: '#0CC0DF',
  onAction: '#10233A',
  disabled: '#D8CCD3',
  track: '#FFFFFF',
  tintBlue: '#CDF2FB',
  tintCoral: '#FFDCD3',
  tintMagenta: '#FFD3EA',
  tintYellow: '#FFEDB0',
  tintGreen: '#D9F2CD',
};

export const darkPalette: StoryPalette = {
  isDark: true,
  ground: '#1B1422',
  surface: '#271E30',
  header: '#271E30',
  headerInk: '#FED65F',
  headerParent: '#271E30',
  headerParentInk: '#FF6EBD',
  ink: '#FBF3F8',
  inkMuted: '#BDAFC0',
  outline: '#3A2E45',
  shadowInk: '#0E0A14',
  paperFleck: '#2A2134',
  line: '#3A2E45',
  action: '#0CC0DF',
  onAction: '#10233A',
  disabled: '#4A3F55',
  track: '#271E2F',
  tintBlue: '#17333F',
  tintCoral: '#46261F',
  tintMagenta: '#45203D',
  tintYellow: '#393220',
  tintGreen: '#1E3524',
};

/** The five tints in a fixed order, so a caller can index into them. */
export function tints(p: StoryPalette): string[] {
  return [p.tintYellow, p.tintBlue, p.tintMagenta, p.tintCoral, p.tintGreen];
}

/** Tint for a 0-based option index, wrapping. */
export function tintForIndex(p: StoryPalette, index: number): string {
  const all = tints(p);
  return all[((index % all.length) + all.length) % all.length];
}

// Shape
export const radiusTile = 20;
export const radiusButton = 16;
/** How far a sticker sits off the page, and so how far it travels on press. */
export const depth = 4;
export const outlineWidth = 3;
export const outlineWidthThin = 2.5;
export const ringWidth = 3;

/**
 * The hard offset shadow that lifts a sticker off the page. No blur at all;
 * collapses on press so the sticker presses flat.
 */
export function cardShadow(
  p: StoryPalette,
  opts: { pressed?: boolean; depth?: number } = {},
): ViewStyle {
  const d = opts.depth ?? depth;
  if (opts.pressed || d <= 0) return {};
  return {
    shadowColor: p.shadowInk,
    shadowOffset: { width: d, height: d },
    shadowOpacity: 1,
    shadowRadius: 0,
  };
}

const fredoka: Record<number, string> = {
  300: 'Fredoka_300Light',
  400: 'Fredoka_400Regular',
  500: 'Fredoka_500Medium',
  600: 'Fredoka_600SemiBold',
  700: 'Fredoka_700Bold',
};

const nunito: Record<number, string> = {
  200: 'Nunito_200ExtraLight',
  300: 'Nunito_300Light',
  400: 'Nunito_400Regular',
  500: 'Nunito_500Medium',
  600: 'Nunito_600SemiBold',
  700: 'Nunito_700Bold',
  800: 'Nunito_800ExtraBold',
  900: 'Nunito_900Black',
};

function nearest(table: Record<number, string>, weight: number): string {
  const keys = Object.keys(table).map(Number);
  let best = keys[0];
  for (const k of keys) if (Math.abs(k - weight) < Math.abs(best - weight)) best = k;
  return table[best];
}

/** Display face. Headers, option labels, button labels, progress text. */
export function display(
  size: number,
  color: string,
  weight = 600,
  tracking = 0,
): TextStyle {
  return {
    fontFamily: nearest(fredoka, weight),
    fontSize: size,
    color,
    letterSpacing: tracking,
  };
}

/** Body face. Sprout's dialogue and helper text. */
export function body(
  size = 15,
  color: string,
  weight = 400,
  height = 1.5,
): TextStyle {
  return {
    fontFamily: nearest(nunito, weight),
    fontSize: size,
    color,
    lineHeight: Math.round(size * height),
  };
}

/** The reader's "Paper" page, warmer than "White". */
export const readingPaper = '#FFF4DA';

export function readingBackground(theme: string): string {
  switch (theme) {
    case 'dark':
      return darkPalette.ground;
    case 'white':
      return lightPalette.surface;
    default:
      return readingPaper;
  }
}

/** Mixes two #RRGGBB colours, t from 0 (a) to 1 (b). */
export function lerpColor(a: string, b: string, t: number): string {
  const pa = hexToRgb(a);
  const pb = hexToRgb(b);
  const mix = pa.map((v, i) => Math.round(v + (pb[i] - v) * t));
  return rgbToHex(mix[0], mix[1], mix[2]);
}

export function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 8 ? h.slice(2) : h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex(r: number, g: number, b: number): string {
  const c = (v: number) => Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0');
  return `#${c(r)}${c(g)}${c(b)}`.toUpperCase();
}

/** #RRGGBB with an alpha, as rgba(). */
export function withAlpha(hex: string, alpha: number): string {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r},${g},${b},${alpha})`;
}
