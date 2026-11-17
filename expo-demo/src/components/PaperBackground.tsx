import React, { useMemo } from 'react';
import { StyleSheet, View, type ViewStyle } from 'react-native';
import Svg, { Circle, Defs, Pattern, Rect } from 'react-native-svg';

import { usePalette } from '../theme/ThemeProvider';

const TILE = 120;

/**
 * The tile's flecks, generated once from a fixed seed so the paper looks the
 * same on every screen and every launch.
 */
const FLECKS = (() => {
  let seed = 20260401;
  const rand = () => {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 2147483648;
  };
  return Array.from({ length: 26 }, () => ({
    x: rand() * TILE,
    y: rand() * TILE,
    r: 0.6 + rand() * 1.1,
    o: 0.25 + rand() * 0.45,
  }));
})();

/**
 * The speckled sheet every screen is drawn on. Deliberately near-invisible:
 * it stops a large flat fill reading as a blank screen.
 */
export function PaperBackground({
  children,
  style,
}: {
  children?: React.ReactNode;
  style?: ViewStyle;
}) {
  const palette = usePalette();
  const pattern = useMemo(
    () => (
      <Svg style={StyleSheet.absoluteFill} pointerEvents="none">
        <Defs>
          <Pattern id="paper" patternUnits="userSpaceOnUse" width={TILE} height={TILE}>
            {FLECKS.map((f, i) => (
              <Circle
                key={i}
                cx={f.x}
                cy={f.y}
                r={f.r}
                fill={palette.paperFleck}
                fillOpacity={f.o}
              />
            ))}
          </Pattern>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill="url(#paper)" />
      </Svg>
    ),
    [palette.paperFleck],
  );
  return (
    <View style={[{ flex: 1, backgroundColor: palette.ground }, style]}>
      {pattern}
      {children}
    </View>
  );
}
