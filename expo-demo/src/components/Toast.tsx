import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { usePalette } from '../theme/ThemeProvider';
import { body, cardShadow, display, outlineWidth, radiusButton } from '../theme/palette';

/**
 * Stands in for Flutter's SnackBar: one message at a time over the bottom of
 * the screen, staying up across screen changes (the coin toast that follows
 * a quiz lands on the reader after it).
 */

type Toast = {
  id: number;
  message?: string;
  coins?: number;
  action?: { label: string; onPress: () => void };
  duration: number;
};

type ToastApi = {
  show(message: string, opts?: { action?: Toast['action']; duration?: number }): void;
  /** The "+5 coins!" sticker. */
  coins(coins: number): void;
};

const ToastContext = createContext<ToastApi | null>(null);

let toastId = 1;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toast, setToast] = useState<Toast | null>(null);

  const api = useRef<ToastApi>({
    show: (message, opts) =>
      setToast({ id: toastId++, message, action: opts?.action, duration: opts?.duration ?? 3500 }),
    coins: (coins) => setToast({ id: toastId++, coins, duration: 2000 }),
  }).current;

  return (
    <ToastContext.Provider value={api}>
      {children}
      {toast && <ToastView key={toast.id} toast={toast} onDone={() => setToast(null)} />}
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const api = useContext(ToastContext);
  if (!api) throw new Error('useToast outside ToastProvider');
  return api;
}

function ToastView({ toast, onDone }: { toast: Toast; onDone: () => void }) {
  const palette = usePalette();
  const insets = useSafeAreaInsets();
  const opacity = useRef(new Animated.Value(0)).current;

  const hide = useCallback(() => {
    Animated.timing(opacity, { toValue: 0, duration: 180, useNativeDriver: true }).start(onDone);
  }, [onDone, opacity]);

  useEffect(() => {
    Animated.timing(opacity, { toValue: 1, duration: 180, useNativeDriver: true }).start();
    const timer = setTimeout(hide, toast.duration);
    return () => clearTimeout(timer);
  }, [hide, opacity, toast.duration]);

  const isCoins = toast.coins != null;
  return (
    <Animated.View
      pointerEvents="box-none"
      style={[styles.holder, { bottom: insets.bottom + 90, opacity }]}
    >
      {isCoins ? (
        <View
          style={[
            styles.coins,
            {
              backgroundColor: palette.tintYellow,
              borderColor: palette.outline,
              ...cardShadow(palette, { depth: 3 }),
            },
          ]}
        >
          <Text style={[display(18, palette.ink, 700), { textAlign: 'center' }]}>
            🪙 +{toast.coins} coins!
          </Text>
        </View>
      ) : (
        <View style={[styles.bar, { backgroundColor: palette.ink }]}>
          <Text style={[body(15, palette.ground, 600, 1.35), { flex: 1 }]}>{toast.message}</Text>
          {toast.action && (
            <Pressable
              onPress={() => {
                toast.action?.onPress();
                hide();
              }}
              hitSlop={10}
            >
              <Text style={display(15, palette.action, 700)}>{toast.action.label}</Text>
            </Pressable>
          )}
        </View>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  holder: { position: 'absolute', left: 16, right: 16, alignItems: 'stretch' },
  coins: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: radiusButton,
    borderWidth: outlineWidth,
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 10,
  },
});
