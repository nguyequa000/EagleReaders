import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';

import { darkPalette, lightPalette, type StoryPalette } from './palette';

export type ThemeMode = 'system' | 'light' | 'dark';

const KEY = 'story.themeMode';

/**
 * The order the toggle walks through. System sits between the two so a child
 * who taps past the mode they wanted reaches it again in three taps.
 */
const CYCLE: ThemeMode[] = ['system', 'light', 'dark'];

type ThemeValue = {
  mode: ThemeMode;
  palette: StoryPalette;
  next: () => void;
  label: string;
  icon: 'brightness-auto' | 'light-mode' | 'dark-mode';
};

const ThemeContext = createContext<ThemeValue | null>(null);

/**
 * Which theme the app draws in, and the one place that decides it. Defaults to
 * following the device: a phone already in dark mode at bedtime should not be
 * handed a white screen.
 */
export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const scheme = useColorScheme();
  const [mode, setMode] = useState<ThemeMode>('system');

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((stored) => {
        if (stored === 'light' || stored === 'dark' || stored === 'system') setMode(stored);
      })
      .catch(() => {});
  }, []);

  const next = useCallback(() => {
    setMode((current) => {
      const value = CYCLE[(CYCLE.indexOf(current) + 1) % CYCLE.length];
      AsyncStorage.setItem(KEY, value).catch(() => {});
      return value;
    });
  }, []);

  const value = useMemo<ThemeValue>(() => {
    const dark = mode === 'dark' || (mode === 'system' && scheme === 'dark');
    return {
      mode,
      palette: dark ? darkPalette : lightPalette,
      next,
      label:
        mode === 'system'
          ? 'Theme: follows your device'
          : mode === 'light'
            ? 'Theme: day'
            : 'Theme: night',
      icon: mode === 'system' ? 'brightness-auto' : mode === 'light' ? 'light-mode' : 'dark-mode',
    };
  }, [mode, scheme, next]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

/**
 * Draws its children in a fixed palette whatever the app's mode: the reader's
 * toolbar always agrees with the page under it.
 */
export function PaletteOverride({ palette, children }: { palette: StoryPalette; children: React.ReactNode }) {
  const value = useTheme();
  return <ThemeContext.Provider value={{ ...value, palette }}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error('useTheme outside ThemeProvider');
  return value;
}

export function usePalette(): StoryPalette {
  return useTheme().palette;
}
