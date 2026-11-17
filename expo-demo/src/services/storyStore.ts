import {
  collection,
  doc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  type CollectionReference,
} from 'firebase/firestore';

import { storyConfigFromMap, type StoryConfig } from '../story/model';
import { childRef } from './childProfiles';
import { changesOf, noChanges, type ChangeSource } from './firestoreChanges';

/**
 * Children's own stories, at `parents/{uid}/children/{childId}/stories/{id}`,
 * with the Flutter app's fields.
 */
export const DEFAULT_TITLE = 'My Story';

export function countWords(text: string): number {
  const t = text.trim();
  return t ? t.split(/\s+/).length : 0;
}

/** A story the child is writing in Advanced writer mode. */
export type StoryDraft = {
  title: string;
  mode: 'free' | 'guided';
  text: string;
  beginning?: string | null;
  middle?: string | null;
  end?: string | null;
  hero: string;
  heroName?: string | null;
  mood?: string | null;
  setting?: string | null;
  ideasShown: number;
  config?: Record<string, any> | null;
};

export function freeDraft(d: Omit<StoryDraft, 'mode' | 'text'> & { text: string }): StoryDraft {
  return { ...d, mode: 'free', text: d.text.trim() };
}

export function guidedDraft(
  d: Omit<StoryDraft, 'mode' | 'text'> & { beginning: string; middle: string; end: string },
): StoryDraft {
  const parts = [d.beginning, d.middle, d.end].map((p) => p.trim());
  return {
    ...d,
    mode: 'guided',
    beginning: parts[0],
    middle: parts[1],
    end: parts[2],
    text: parts.filter((p) => p).join('\n\n'),
  };
}

export const effectiveTitle = (d: StoryDraft) => (d.title.trim() ? d.title.trim() : DEFAULT_TITLE);
export const draftIsEmpty = (d: StoryDraft) => !d.text.trim() && !d.title.trim();

function draftToMap(d: StoryDraft): Record<string, any> {
  return {
    title: effectiveTitle(d),
    mode: d.mode,
    writerLevel: 'advanced',
    hero: d.hero,
    heroName: d.heroName ?? null,
    mood: d.mood ?? null,
    setting: d.setting ?? null,
    text: d.text,
    beginning: d.beginning ?? null,
    middle: d.middle ?? null,
    end: d.end ?? null,
    totalWords: countWords(d.text),
    ideasShown: d.ideasShown,
    ...(d.config ? { config: d.config } : {}),
  };
}

/** A saved story as the child's dashboard lists it. */
export type StoredStory = {
  id: string;
  title: string;
  writerLevel: 'advanced' | 'beginning';
  completed: boolean;
  text: string;
  mode: string;
  beginning: string;
  middle: string;
  end: string;
  ideasShown: number;
  pages: string[];
  choices: string[];
  questions: Record<string, any>[];
  page: number;
  chapters: number;
  config: StoryConfig;
  updatedAt: number | null;
  completedAt: number | null;
};

export const byAi = (s: StoredStory) => s.writerLevel === 'beginning';

function storyFromMap(id: string, m: Record<string, any>): StoredStory {
  const time = (v: unknown) => (v instanceof Timestamp ? v.toMillis() : null);
  const strings = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
  const str = (v: unknown, d = '') => (typeof v === 'string' ? v : d);
  const num = (v: unknown, d: number) => (typeof v === 'number' ? Math.trunc(v) : d);
  const configMap = m.config && typeof m.config === 'object' ? m.config : null;
  return {
    id,
    title: str(m.title, DEFAULT_TITLE),
    writerLevel: m.writerLevel === 'beginning' ? 'beginning' : 'advanced',
    completed: m.completedAt != null,
    text: str(m.text),
    mode: str(m.mode, 'free'),
    beginning: str(m.beginning),
    middle: str(m.middle),
    end: str(m.end),
    ideasShown: num(m.ideasShown, 0),
    pages: strings(m.pages),
    choices: strings(m.choices),
    questions: Array.isArray(m.questions) ? m.questions.filter((q: unknown) => q && typeof q === 'object') : [],
    page: num(m.page, 0),
    chapters: num(m.chapters, 1),
    config: configMap
      ? storyConfigFromMap(configMap)
      : {
          hero: { character: str(m.hero) || null, name: str(m.heroName) || null },
          mood: str(m.mood) || null,
          setting: str(m.setting) || null,
          idea: '',
        },
    updatedAt: time(m.updatedAt),
    completedAt: time(m.completedAt),
  };
}

/** A finished story, as the writer hands it back to the flow. */
export type SavedStory = { id: string; title: string; text: string };

function storiesOf(childId: string): CollectionReference {
  const child = childRef(childId);
  if (!child) throw new Error('Cannot save a story while signed out.');
  return collection(child, 'stories');
}

async function write(
  childId: string,
  fields: Record<string, any>,
  id: string | null | undefined,
  completed: boolean,
): Promise<string> {
  const stories = storiesOf(childId);
  const ref = id ? doc(stories, id) : doc(stories);
  const now = serverTimestamp();
  await setDoc(
    ref,
    {
      ...fields,
      ...(id ? {} : { createdAt: now }),
      updatedAt: now,
      // A finished story stays finished: a later save leaves completedAt.
      ...(completed ? { completedAt: now } : id ? {} : { completedAt: null }),
    },
    { merge: true },
  );
  return ref.id;
}

export const StoryStore = {
  saveDraft: (childId: string, draft: StoryDraft, id?: string | null) =>
    write(childId, draftToMap(draft), id, false),

  /** Saves a story Sprout is writing with the child (Beginning writer). */
  saveAiStory: (childId: string, fields: Record<string, any>, id: string | null | undefined, completed: boolean) =>
    write(childId, { ...fields, writerLevel: 'beginning', mode: 'ai' }, id, completed),

  /** The child's stories, most recently changed first. */
  async loadStories(childId: string): Promise<StoredStory[]> {
    let stories: CollectionReference;
    try {
      stories = storiesOf(childId);
    } catch {
      return [];
    }
    const snap = await getDocs(stories);
    return snap.docs
      .map((d) => storyFromMap(d.id, d.data()))
      .sort((a, b) => (b.updatedAt ?? 0) - (a.updatedAt ?? 0));
  },

  changes(childId: string): ChangeSource {
    try {
      return changesOf(storiesOf(childId));
    } catch {
      return noChanges;
    }
  },

  async complete(childId: string, draft: StoryDraft, id?: string | null): Promise<SavedStory> {
    const savedId = await write(childId, draftToMap(draft), id, true);
    return { id: savedId, title: effectiveTitle(draft), text: draft.text };
  },
};
