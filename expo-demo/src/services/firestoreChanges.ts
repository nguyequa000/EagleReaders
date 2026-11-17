import {
  onSnapshot,
  type CollectionReference,
  type DocumentReference,
  type Query,
} from 'firebase/firestore';
import { useEffect, useRef } from 'react';

/**
 * A "something changed" signal: call it with a callback, get back an
 * unsubscribe function. The Flutter app's `changes()` streams, without the
 * stream machinery.
 */
export type ChangeSource = (onChange: () => void) => () => void;

export const noChanges: ChangeSource = () => () => {};

/**
 * Turns a Firestore listener into a change signal. The first snapshot is
 * dropped: it is the state the screen has just loaded, so only later ones —
 * writes from this device or another one on the same account — are changes.
 */
export function changesOf(
  ref: DocumentReference | CollectionReference | Query,
): ChangeSource {
  return (onChange) => {
    let first = true;
    try {
      return onSnapshot(
        ref as Query,
        () => {
          if (first) {
            first = false;
            return;
          }
          onChange();
        },
        // A dropped listener just means the screen stops updating live.
        () => {},
      );
    } catch {
      return () => {};
    }
  };
}

export function mergeChanges(sources: ChangeSource[]): ChangeSource {
  return (onChange) => {
    const stops = sources.map((s) => s(onChange));
    return () => stops.forEach((stop) => stop());
  };
}

/**
 * Keeps a screen current while the same account is open on another device:
 * re-runs [reload] whenever any source fires, with one write's burst of
 * changes collapsed into one reload. [key] re-subscribes when it changes (a
 * screen whose list of children changed underneath it).
 */
export function useLiveRefresh(
  sources: () => ChangeSource[],
  reload: () => void | Promise<void>,
  key: string = '',
) {
  const reloadRef = useRef(reload);
  reloadRef.current = reload;
  const sourcesRef = useRef(sources);
  sourcesRef.current = sources;

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    let stops: (() => void)[] = [];
    try {
      stops = sourcesRef.current().map((source) =>
        source(() => {
          if (timer) clearTimeout(timer);
          timer = setTimeout(() => {
            void reloadRef.current();
          }, 300);
        }),
      );
    } catch {
      // A service that cannot reach Firebase costs the screen its live updates.
    }
    return () => {
      if (timer) clearTimeout(timer);
      stops.forEach((stop) => stop());
    };
  }, [key]);
}
