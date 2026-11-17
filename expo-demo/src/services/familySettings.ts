import { doc, getDoc, setDoc } from 'firebase/firestore';
import { updateProfile } from 'firebase/auth';

import { auth } from '../firebase';
import type { ActivityEvent } from './activity';
import { parentRef, requireParent } from './childProfiles';
import { changesOf, mergeChanges, noChanges, type ChangeSource } from './firestoreChanges';
import { ageBandFromName, FALLBACK_BAND, type AgeBand } from './readerAudience';

/** The parent's switches from Parent Settings, for the whole family. */
export type AiSettings = {
  aiStories: boolean;
  aiQuizzes: boolean;
  sproutIdeas: boolean;
  readAloud: boolean;
  readingReminder: boolean;
};

export const defaultAiSettings: AiSettings = {
  aiStories: true,
  aiQuizzes: true,
  sproutIdeas: true,
  readAloud: true,
  readingReminder: false,
};

function aiFromMap(map: Record<string, any> | undefined): AiSettings {
  const read = (key: keyof AiSettings) =>
    typeof map?.[key] === 'boolean' ? (map[key] as boolean) : defaultAiSettings[key];
  return {
    aiStories: read('aiStories'),
    aiQuizzes: read('aiQuizzes'),
    sproutIdeas: read('sproutIdeas'),
    readAloud: read('readAloud'),
    readingReminder: read('readingReminder'),
  };
}

/** One child's age band and daily reading limit. */
export type ChildRules = {
  ageBand: AgeBand;
  /** Minutes of reading a day, or null for no limit. */
  dailyLimitMinutes: number | null;
  /** The day (yyyy-MM-dd) a grown-up lifted the limit, if any. */
  limitUnlockedOn: string | null;
};

export const defaultChildRules: ChildRules = {
  ageBand: FALLBACK_BAND,
  dailyLimitMinutes: null,
  limitUnlockedOn: null,
};

function rulesFromMap(map: Record<string, any> | undefined): ChildRules {
  return {
    ageBand: ageBandFromName(map?.ageBand),
    dailyLimitMinutes: typeof map?.dailyLimitMinutes === 'number' ? Math.trunc(map.dailyLimitMinutes) : null,
    limitUnlockedOn: typeof map?.limitUnlockedOn === 'string' ? map.limitUnlockedOn : null,
  };
}

/** `yyyy-MM-dd` in local time: what "today" means to a child. */
export function dayKey(time: Date): string {
  const pad = (n: number, w = 2) => String(n).padStart(w, '0');
  return `${pad(time.getFullYear(), 4)}-${pad(time.getMonth() + 1)}-${pad(time.getDate())}`;
}

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export function limitReached(rules: ChildRules, minutesToday: number, now: Date): boolean {
  if (rules.dailyLimitMinutes == null || rules.limitUnlockedOn === dayKey(now)) return false;
  return minutesToday >= rules.dailyLimitMinutes;
}

export function minutesReadToday(events: ActivityEvent[], now: Date): number {
  return events
    .filter((e) => e.type === 'reading_session' && sameDay(new Date(e.ts), now))
    .reduce((sum, e) => sum + (Number(e.data.minutes) || 0), 0);
}

export function readToday(events: ActivityEvent[], now: Date): boolean {
  return events.some(
    (e) => (e.type === 'book_opened' || e.type === 'reading_session') && sameDay(new Date(e.ts), now),
  );
}

/**
 * Parent Settings, kept in Firestore so every device in the family sees the
 * same switches: a `settings` map on `parents/{uid}`, and rules as fields on
 * each child's document.
 */
export const FamilySettings = {
  /** The switches as last loaded or saved on this device. */
  ai: { ...defaultAiSettings } as AiSettings,

  async load(): Promise<AiSettings> {
    const parent = parentRef();
    if (!parent) return (FamilySettings.ai = { ...defaultAiSettings });
    const snap = await getDoc(parent);
    return (FamilySettings.ai = aiFromMap(snap.data()?.settings));
  },

  async save(settings: AiSettings): Promise<void> {
    await setDoc(requireParent('change settings'), { settings }, { merge: true });
    FamilySettings.ai = settings;
  },

  async loadDisplayName(): Promise<string | null> {
    const parent = parentRef();
    if (!parent) return null;
    const name = (await getDoc(parent)).data()?.displayName;
    return typeof name === 'string' && name.trim() ? name.trim() : null;
  },

  /** The name they set, else the start of their email, else null. */
  async loadGreetingName(): Promise<string | null> {
    const name = await FamilySettings.loadDisplayName();
    if (name) return name;
    const email = auth.currentUser?.email;
    return email ? email.split('@')[0] : null;
  },

  async saveDisplayName(name: string): Promise<void> {
    await setDoc(requireParent('change your name'), { displayName: name.trim() }, { merge: true });
    if (auth.currentUser) await updateProfile(auth.currentUser, { displayName: name.trim() });
  },

  async loadChild(childId: string): Promise<ChildRules> {
    const parent = parentRef();
    if (!parent) return { ...defaultChildRules };
    const snap = await getDoc(doc(parent, 'children', childId));
    return rulesFromMap(snap.data());
  },

  async saveChild(childId: string, rules: ChildRules): Promise<void> {
    await setDoc(
      doc(requireParent('change limits'), 'children', childId),
      { ageBand: rules.ageBand, dailyLimitMinutes: rules.dailyLimitMinutes },
      { merge: true },
    );
  },

  /** Lifts today's limit for [childId] (a grown-up typed the PIN). */
  async unlockToday(childId: string): Promise<void> {
    await setDoc(
      doc(requireParent('unlock'), 'children', childId),
      { limitUnlockedOn: dayKey(new Date()) },
      { merge: true },
    );
  },

  changes(childId?: string): ChangeSource {
    const parent = parentRef();
    if (!parent) return noChanges;
    return mergeChanges([
      changesOf(parent),
      ...(childId ? [changesOf(doc(parent, 'children', childId))] : []),
    ]);
  },
};
