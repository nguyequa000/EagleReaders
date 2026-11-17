import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Animated,
  Dimensions,
  Easing,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';

/**
 * A small stack navigator with Flutter's Navigator semantics, so each screen
 * ports one to one: push() resolves with whatever the pushed screen pops
 * with, replace() swaps the top screen (and hands the caller's pending result
 * to the new one), and dialogs and bottom sheets are entries on the same
 * stack that pop() closes.
 */

type Kind = 'page' | 'dialog' | 'sheet';

type Entry = {
  key: number;
  kind: Kind;
  element: React.ReactElement;
  resolve: (value: unknown) => void;
  leaving?: boolean;
  /** Tapping outside a dialog or sheet closes it. */
  dismissible?: boolean;
};

export type Nav = {
  push<T = unknown>(element: React.ReactElement): Promise<T | undefined>;
  replace(element: React.ReactElement): void;
  pop(result?: unknown): void;
  /** Pops [count] entries at once, the last with [result]. */
  popMany(count: number, result?: unknown): void;
  /** Clears the stack and shows [element] alone. */
  resetTo(element: React.ReactElement): void;
  showDialog<T = unknown>(
    element: React.ReactElement,
    opts?: { dismissible?: boolean },
  ): Promise<T | undefined>;
  showSheet<T = unknown>(
    element: React.ReactElement,
    opts?: { dismissible?: boolean },
  ): Promise<T | undefined>;
};

const NavContext = createContext<Nav | null>(null);
const RouteContext = createContext<{ canPop: boolean; visible: boolean }>({
  canPop: false,
  visible: true,
});

export function useNav(): Nav {
  const nav = useContext(NavContext);
  if (!nav) throw new Error('useNav outside NavigatorHost');
  return nav;
}

/** Whether this screen has another screen under it to go back to. */
export function useRoute() {
  return useContext(RouteContext);
}

let nextKey = 1;

export function NavigatorHost({ initial }: { initial: React.ReactElement }) {
  const [entries, setEntries] = useState<Entry[]>(() => [
    { key: nextKey++, kind: 'page', element: initial, resolve: () => {} },
  ]);
  const entriesRef = useRef(entries);
  entriesRef.current = entries;

  const remove = useCallback((key: number) => {
    setEntries((list) => list.filter((e) => e.key !== key));
  }, []);

  const add = useCallback(
    (element: React.ReactElement, kind: Kind, dismissible = true) =>
      new Promise<any>((resolve) => {
        setEntries((list) => [
          ...list,
          { key: nextKey++, kind, element, resolve, dismissible },
        ]);
      }),
    [],
  );

  const popInternal = useCallback((count: number, result?: unknown) => {
    setEntries((list) => {
      const live = list.filter((e) => !e.leaving);
      // Never pop the last page.
      let pages = live.filter((e) => e.kind === 'page').length;
      let remaining = count;
      const next = [...list];
      for (let i = next.length - 1; i >= 0 && remaining > 0; i--) {
        const entry = next[i];
        if (entry.leaving) continue;
        if (entry.kind === 'page') {
          if (pages <= 1) break;
          pages--;
        }
        next[i] = { ...entry, leaving: true };
        const value = remaining === 1 ? result : undefined;
        // Resolved after the state update so the caller sees the stack as it
        // will be.
        setTimeout(() => entry.resolve(value), 0);
        remaining--;
      }
      return next;
    });
  }, []);

  const nav = useMemo<Nav>(
    () => ({
      push: (element) => add(element, 'page'),
      replace: (element) => {
        setEntries((list) => {
          const index = findLastIndex(list, (e) => e.kind === 'page' && !e.leaving);
          if (index < 0) return list;
          const old = list[index];
          const next = list.filter((e, i) => i <= index || e.leaving);
          // The new screen inherits the old one's waiting caller.
          next[index] = {
            key: nextKey++,
            kind: 'page',
            element,
            resolve: old.resolve,
          };
          return next;
        });
      },
      pop: (result) => popInternal(1, result),
      popMany: (count, result) => popInternal(count, result),
      resetTo: (element) => {
        const old = entriesRef.current;
        setEntries([{ key: nextKey++, kind: 'page', element, resolve: () => {} }]);
        setTimeout(() => old.forEach((e) => e.resolve(undefined)), 0);
      },
      showDialog: (element, opts) => add(element, 'dialog', opts?.dismissible ?? true),
      showSheet: (element, opts) => add(element, 'sheet', opts?.dismissible ?? true),
    }),
    [add, popInternal],
  );

  const live = entries.filter((e) => !e.leaving);
  const topPage = findLastIndex(entries, (e) => e.kind === 'page' && !e.leaving);
  const pageCount = live.filter((e) => e.kind === 'page').length;

  return (
    <NavContext.Provider value={nav}>
      <View style={styles.fill}>
        {entries.map((entry, index) => {
          // Pages under the top one stay mounted (keeping their state, like
          // Flutter's routes) but hidden.
          const isPage = entry.kind === 'page';
          const visible = entry.leaving || index >= topPage;
          const pagesBelow = entries
            .slice(0, index)
            .filter((e) => e.kind === 'page' && !e.leaving).length;
          return (
            <RouteContext.Provider
              key={entry.key}
              value={{ canPop: isPage ? pagesBelow > 0 : pageCount > 0, visible }}
            >
              {isPage ? (
                <PageLayer
                  visible={visible}
                  first={index === 0}
                  leaving={!!entry.leaving}
                  onExited={() => remove(entry.key)}
                >
                  {entry.element}
                </PageLayer>
              ) : (
                <OverlayLayer
                  kind={entry.kind}
                  visible={visible}
                  leaving={!!entry.leaving}
                  onExited={() => remove(entry.key)}
                  onDismiss={entry.dismissible ? () => nav.pop() : undefined}
                >
                  {entry.element}
                </OverlayLayer>
              )}
            </RouteContext.Provider>
          );
        })}
      </View>
    </NavContext.Provider>
  );
}

function findLastIndex<T>(list: T[], test: (item: T) => boolean): number {
  for (let i = list.length - 1; i >= 0; i--) if (test(list[i])) return i;
  return -1;
}

function PageLayer({
  children,
  visible,
  first,
  leaving,
  onExited,
}: {
  children: React.ReactNode;
  visible: boolean;
  first: boolean;
  leaving: boolean;
  onExited: () => void;
}) {
  const width = Dimensions.get('window').width;
  const x = useRef(new Animated.Value(first ? 0 : width)).current;

  useEffect(() => {
    if (first) return;
    Animated.timing(x, {
      toValue: 0,
      duration: 240,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [first, x]);

  useEffect(() => {
    if (!leaving) return;
    Animated.timing(x, {
      toValue: width,
      duration: 200,
      easing: Easing.in(Easing.cubic),
      useNativeDriver: true,
    }).start(() => onExited());
  }, [leaving, onExited, width, x]);

  return (
    <Animated.View
      pointerEvents={visible && !leaving ? 'auto' : 'none'}
      style={[
        StyleSheet.absoluteFill,
        { transform: [{ translateX: x }] },
        !visible && styles.hidden,
      ]}
    >
      {children}
    </Animated.View>
  );
}

function OverlayLayer({
  children,
  kind,
  visible,
  leaving,
  onExited,
  onDismiss,
}: {
  children: React.ReactNode;
  kind: Kind;
  visible: boolean;
  leaving: boolean;
  onExited: () => void;
  onDismiss?: () => void;
}) {
  const t = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(t, {
      toValue: 1,
      duration: 200,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [t]);

  useEffect(() => {
    if (!leaving) return;
    Animated.timing(t, { toValue: 0, duration: 160, useNativeDriver: true }).start(() =>
      onExited(),
    );
  }, [leaving, onExited, t]);

  const sheet = kind === 'sheet';
  const height = Dimensions.get('window').height;
  return (
    <View
      pointerEvents={visible && !leaving ? 'auto' : 'none'}
      style={[StyleSheet.absoluteFill, !visible && styles.hidden]}
    >
      <Animated.View style={[StyleSheet.absoluteFill, styles.backdrop, { opacity: t }]}>
        <Pressable style={styles.fill} onPress={onDismiss} accessibilityLabel="Close" />
      </Animated.View>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={[styles.fill, sheet ? styles.sheetHolder : styles.dialogHolder]}
        pointerEvents="box-none"
      >
        <Animated.View
          style={
            sheet
              ? { transform: [{ translateY: t.interpolate({ inputRange: [0, 1], outputRange: [height, 0] }) }] }
              : {
                  opacity: t,
                  transform: [{ scale: t.interpolate({ inputRange: [0, 1], outputRange: [0.94, 1] }) }],
                  width: '100%',
                  alignItems: 'center',
                }
          }
        >
          {children}
        </Animated.View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
  hidden: { opacity: 0 },
  backdrop: { backgroundColor: 'rgba(0,0,0,0.45)' },
  sheetHolder: { justifyContent: 'flex-end' },
  dialogHolder: { justifyContent: 'center', paddingHorizontal: 24 },
});
