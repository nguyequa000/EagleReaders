import React from 'react';
import Svg, { Circle, Defs, Ellipse, G, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

import { hexToRgb, lerpColor, rgbToHex } from '../theme/palette';

/**
 * The places a story can happen in, drawn as inked cut-out shapes. Scenes are
 * data, not drawing code; ported from lib/screens/story/story_scene.dart.
 */
type Shape = 'hill' | 'sun' | 'cloud' | 'tree' | 'building' | 'star' | 'wave' | 'planet' | 'ring';

type Element = { shape: Shape; x: number; y: number; scale: number; color: string };

export type Scene = { label: string; skyTop: string; skyBottom: string; elements: Element[] };

const el = (shape: Shape, x: number, y: number, scale: number, color: string): Element => ({
  shape,
  x,
  y,
  scale,
  color,
});

const SCENES: Scene[] = [
  {
    label: 'Forest',
    skyTop: '#9ED8F0',
    skyBottom: '#DFF4FC',
    elements: [
      el('sun', 0.82, 0.18, 1.1, '#FFD23F'),
      el('cloud', 0.24, 0.2, 1.0, '#FFFFFF'),
      el('hill', 0.5, 0.7, 1.15, '#9BD98F'),
      el('hill', 0.5, 0.84, 1.0, '#5FAE4B'),
      el('tree', 0.13, 0.74, 1.25, '#2F7D32'),
      el('tree', 0.33, 0.8, 0.85, '#3E9440'),
      el('tree', 0.72, 0.77, 1.05, '#2F7D32'),
      el('tree', 0.9, 0.83, 0.8, '#3E9440'),
    ],
  },
  {
    label: 'Ocean',
    skyTop: '#8FD6EE',
    skyBottom: '#DCF3FA',
    elements: [
      el('sun', 0.2, 0.17, 1.0, '#FFD23F'),
      el('cloud', 0.74, 0.19, 1.1, '#FFFFFF'),
      el('wave', 0.5, 0.62, 1.0, '#7FD4E6'),
      el('wave', 0.5, 0.75, 1.0, '#35A6C4'),
      el('wave', 0.5, 0.89, 1.0, '#17708C'),
    ],
  },
  {
    label: 'City',
    skyTop: '#C9BCEE',
    skyBottom: '#FBE3EC',
    elements: [
      el('sun', 0.86, 0.16, 0.9, '#FFD23F'),
      el('building', 0.1, 0.78, 1.25, '#A99BDC'),
      el('building', 0.28, 0.78, 0.9, '#6F5EAE'),
      el('building', 0.45, 0.78, 1.4, '#8E7FC4'),
      el('building', 0.63, 0.78, 1.0, '#6F5EAE'),
      el('building', 0.82, 0.78, 1.2, '#A99BDC'),
      el('hill', 0.5, 0.93, 0.9, '#4A4463'),
    ],
  },
  {
    label: 'Outer Space',
    skyTop: '#241F5C',
    skyBottom: '#4A3C77',
    elements: [
      el('star', 0.12, 0.16, 1.0, '#FFF0C2'),
      el('star', 0.3, 0.09, 0.7, '#FFF0C2'),
      el('star', 0.55, 0.2, 0.8, '#FFFFFF'),
      el('star', 0.88, 0.13, 1.0, '#FFF0C2'),
      el('star', 0.7, 0.33, 0.6, '#FFFFFF'),
      el('planet', 0.8, 0.3, 1.0, '#C3A9F0'),
      el('ring', 0.8, 0.3, 1.0, '#E0D3F7'),
      el('hill', 0.5, 0.86, 1.0, '#5B4E86'),
    ],
  },
];

export function sceneForLabel(label?: string | null): Scene | null {
  return SCENES.find((s) => s.label === label) ?? null;
}

function mapColors(scene: Scene, f: (c: string) => string): Scene {
  return {
    ...scene,
    skyTop: f(scene.skyTop),
    skyBottom: f(scene.skyBottom),
    elements: scene.elements.map((e) => ({ ...e, color: f(e.color) })),
  };
}

/** The same place in the light the story's mood casts. */
export function sceneForMood(scene: Scene, mood?: string | null): Scene {
  const light = (
    {
      spooky: { wash: '#2B3A6B', amount: 0.34, saturate: 0 },
      funny: { wash: '#FFE27A', amount: 0.2, saturate: 0 },
      calm: { wash: '#E8D9F2', amount: 0.22, saturate: -0.18 },
      adventurous: { wash: '#FFB45C', amount: 0.16, saturate: 0.12 },
    } as Record<string, { wash: string; amount: number; saturate: number }>
  )[mood?.toLowerCase() ?? ''];
  if (!light) return scene;
  return mapColors(scene, (c) => {
    const washed = lerpColor(c, light.wash, light.amount);
    return light.saturate === 0 ? washed : saturate(washed, light.saturate);
  });
}

/** The same scene at night: every colour blended toward the dark ground. */
export function sceneForDark(scene: Scene, ground: string): Scene {
  return {
    ...scene,
    skyTop: lerpColor(scene.skyTop, ground, 0.62),
    skyBottom: lerpColor(scene.skyBottom, ground, 0.52),
    elements: scene.elements.map((e) => ({ ...e, color: lerpColor(e.color, ground, 0.45) })),
  };
}

function saturate(hex: string, delta: number): string {
  const [r, g, b] = hexToRgb(hex).map((v) => v / 255);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h /= 6;
  }
  s = Math.max(0, Math.min(1, s + delta));
  const hue = (p: number, q: number, t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  if (s === 0) return rgbToHex(l * 255, l * 255, l * 255);
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return rgbToHex(
    Math.round(hue(p, q, h + 1 / 3) * 255),
    Math.round(hue(p, q, h) * 255),
    Math.round(hue(p, q, h - 1 / 3) * 255),
  );
}

/** A deterministic value in -1..1, to take the precision off drawn edges. */
function wobble(seed: number): number {
  const v = Math.sin(seed * 12.9898) * 43758.5453;
  return (v - Math.floor(v)) * 2 - 1;
}

export function SceneSvg({
  scene,
  width,
  height,
  outline,
}: {
  scene: Scene;
  width: number;
  height: number;
  outline: string;
}) {
  const shortest = Math.min(width, height);
  const stroke = Math.max(1.4, Math.min(3.2, shortest * 0.018));
  const ink = { stroke: outline, strokeWidth: stroke, strokeLinejoin: 'round' as const, strokeLinecap: 'round' as const };

  const shapes = scene.elements.map((e, index) => {
    const cx = e.x * width;
    const cy = e.y * height;
    const unit = shortest * 0.1 * e.scale;
    switch (e.shape) {
      case 'sun':
        return <Circle key={index} cx={cx} cy={cy} r={unit * 0.85} fill={e.color} {...ink} />;
      case 'star':
        return <Circle key={index} cx={cx} cy={cy} r={unit * 0.16} fill={e.color} />;
      case 'planet':
        return <Circle key={index} cx={cx} cy={cy} r={unit * 0.95} fill={e.color} {...ink} />;
      case 'ring':
        return (
          <Ellipse key={index} cx={cx} cy={cy} rx={unit * 1.6} ry={unit * 0.35} fill={e.color} fillOpacity={0.85} {...ink} />
        );
      case 'cloud': {
        const lobes = [
          [-0.7, 0.05],
          [0, -0.15],
          [0.7, 0.05],
        ].map(([dx, dy]) => ({ x: cx + dx * unit * 1.4, y: cy + dy * unit * 1.4, r: unit * 0.7 }));
        // Inked lobes first, filled lobes over them: only the outer edge of
        // the line shows, so the cloud reads as one silhouette.
        return (
          <G key={index}>
            {lobes.map((l, i) => (
              <Circle key={`o${i}`} cx={l.x} cy={l.y} r={l.r} fill={e.color} stroke={outline} strokeWidth={stroke * 2} />
            ))}
            {lobes.map((l, i) => (
              <Circle key={`f${i}`} cx={l.x} cy={l.y} r={l.r} fill={e.color} />
            ))}
          </G>
        );
      }
      case 'hill': {
        let crest = `M 0 ${cy + wobble(index) * unit * 0.08}`;
        const segments = 3;
        for (let i = 0; i < segments; i++) {
          const startX = width * (i / segments);
          const endX = width * ((i + 1) / segments);
          const lift = unit * (0.9 + wobble(index * 31 + i) * 0.45);
          const endY = cy + wobble(index * 17 + i) * unit * 0.22;
          crest += ` Q ${(startX + endX) / 2} ${cy - lift} ${endX} ${endY}`;
        }
        return (
          <G key={index}>
            <Path d={`${crest} L ${width} ${height} L 0 ${height} Z`} fill={e.color} />
            <Path d={crest} fill="none" {...ink} />
          </G>
        );
      }
      case 'wave': {
        let crest = `M 0 ${cy}`;
        const step = width / 4;
        for (let i = 0; i < 4; i++) {
          crest += ` Q ${step * i + step * 0.5} ${cy + (i % 2 === 0 ? -unit * 0.4 : unit * 0.4)} ${step * (i + 1)} ${cy}`;
        }
        return (
          <G key={index}>
            <Path d={`${crest} L ${width} ${height} L 0 ${height} Z`} fill={e.color} />
            <Path d={crest} fill="none" {...ink} />
          </G>
        );
      }
      case 'tree': {
        const tiers = [2, 1, 0].map((i) => {
          const top = cy - unit * (1.6 - i * 0.5);
          const half = unit * (0.55 + i * 0.25);
          const bottom = top + unit * 0.85;
          const tip = cx + wobble(index * 7 + i) * unit * 0.06;
          return <Path key={i} d={`M ${tip} ${top} L ${cx - half} ${bottom} L ${cx + half} ${bottom} Z`} fill={e.color} {...ink} />;
        });
        return (
          <G key={index}>
            <Rect x={cx - unit * 0.15} y={cy} width={unit * 0.3} height={unit * 1.1} fill="#8A5A33" {...ink} />
            {tiers}
          </G>
        );
      }
      case 'building': {
        const h = unit * 2.6;
        const windows = [];
        for (let row = 0; row < 3; row++) {
          for (let column = 0; column < 2; column++) {
            windows.push(
              <Rect
                key={`${row}-${column}`}
                x={cx - unit * 0.34 + column * unit * 0.38}
                y={cy - h + unit * 0.32 + row * unit * 0.6}
                width={unit * 0.22}
                height={unit * 0.3}
                fill="#FFD23F"
                stroke={outline}
                strokeWidth={stroke * 0.55}
              />,
            );
          }
        }
        return (
          <G key={index}>
            <Rect x={cx - unit * 0.55} y={cy - h} width={unit * 1.1} height={h} rx={3} fill={e.color} {...ink} />
            {windows}
          </G>
        );
      }
    }
  });

  return (
    <Svg width={width} height={height}>
      <Defs>
        <LinearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={scene.skyTop} />
          <Stop offset="1" stopColor={scene.skyBottom} />
        </LinearGradient>
      </Defs>
      <Rect x={0} y={0} width={width} height={height} fill="url(#sky)" />
      {shapes}
    </Svg>
  );
}
