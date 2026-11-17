import { addDoc, collection, getDocs, orderBy, query, type CollectionReference } from 'firebase/firestore';

import { childRef } from './childProfiles';
import { changesOf, noChanges, type ChangeSource } from './firestoreChanges';

/**
 * Reading-activity tracking, one document per event at
 * `parents/{uid}/children/{childId}/activity/{autoId}`, with the same event
 * shapes as the Flutter app:
 *   book_opened          {title}
 *   book_finished        {title}
 *   reading_session      {title, minutes, bookType}
 *   comprehension_result {title, chapter, score, correct, total}
 *   story_created        {title}
 */
export type ActivityEvent = { type: string; ts: number; data: Record<string, any> };

export type ChildActivityStats = {
  booksFinished: number;
  minutesThisWeek: number;
  storiesCreated: number;
  lastComprehensionScorePct: number | null;
  currentlyReading: string | null;
};

function eventFromJson(json: Record<string, any>): ActivityEvent {
  const { type, ts, ...data } = json;
  return { type: typeof type === 'string' ? type : 'unknown', ts: typeof ts === 'number' ? ts : 0, data };
}

/** Parent-facing one-line summary, shared by the dashboard and profile. */
export function describeEvent(event: ActivityEvent, childName: string): string {
  const d = event.data;
  const title = d.title ?? 'a book';
  switch (event.type) {
    case 'book_opened':
      return `${childName} started reading "${title}"`;
    case 'book_finished':
      return `${childName} finished "${title}"`;
    case 'reading_session':
      return `${childName} read "${title}" for ${d.minutes} min`;
    case 'comprehension_result':
      return `${childName} scored ${d.score ?? ''} on "${title}"`;
    case 'story_created':
      return `${childName} created a new story: "${title}"`;
    case 'coins_earned':
      return d.reason === 'story'
        ? `${childName} earned ${d.coins} coins for creating "${title}"`
        : `${childName} earned ${d.coins} coins for a quiz on "${title}"`;
    case 'reward_redeemed':
      return `${childName} redeemed "${title}" for ${d.coins} coins`;
    case 'coins_refunded':
      return `${childName} got ${d.coins} coins back for "${title}"`;
    default:
      return `${childName}: ${event.type} — "${title}"`;
  }
}

function activityCollection(childId: string): CollectionReference | null {
  const child = childRef(childId);
  return child ? collection(child, 'activity') : null;
}

export const ActivityService = {
  /** Records one event; skipped when no parent is signed in. */
  async logEvent(childId: string, type: string, data: Record<string, any>): Promise<void> {
    const events = activityCollection(childId);
    if (!events) return;
    await addDoc(events, { ...data, type, ts: Date.now() });
  },

  changes(childId: string): ChangeSource {
    const events = activityCollection(childId);
    return events ? changesOf(events) : noChanges;
  },

  /** All of a child's events, oldest first. */
  async getEvents(childId: string): Promise<ActivityEvent[]> {
    const events = activityCollection(childId);
    if (!events) return [];
    const snapshot = await getDocs(query(events, orderBy('ts')));
    return snapshot.docs.map((d) => eventFromJson(d.data()));
  },

  startSession(): number {
    return Date.now();
  },

  async logReadingSession(
    childId: string,
    start: number,
    title: string,
    bookType: string,
  ): Promise<void> {
    const minutes = Math.floor((Date.now() - start) / 60000);
    // Sub-minute sessions are noise on the parent dashboard.
    if (minutes <= 0) return;
    await ActivityService.logEvent(childId, 'reading_session', { title, minutes, bookType });
  },

  statsFrom(events: ActivityEvent[]): ChildActivityStats {
    const booksFinished = new Set(
      events.filter((e) => e.type === 'book_finished').map((e) => e.data.title),
    ).size;
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const minutesThisWeek = events
      .filter((e) => e.type === 'reading_session' && e.ts > weekAgo)
      .reduce((sum, e) => sum + (Number(e.data.minutes) || 0), 0);
    const storiesCreated = events.filter((e) => e.type === 'story_created').length;
    const sorted = [...events].sort((a, b) => a.ts - b.ts);

    let lastComprehensionScorePct: number | null = null;
    const quizzes = sorted.filter((e) => e.type === 'comprehension_result');
    const last = quizzes[quizzes.length - 1];
    if (last) {
      const correct = Number(last.data.correct);
      const total = Number(last.data.total);
      if (!Number.isNaN(correct) && total > 0) lastComprehensionScorePct = (correct / total) * 100;
    }

    let currentlyReading: string | null = null;
    const opened = sorted.filter((e) => e.type === 'book_opened');
    const lastOpened = opened[opened.length - 1];
    if (lastOpened) {
      const title = lastOpened.data.title;
      const finishedSince = sorted.some(
        (e) => e.type === 'book_finished' && e.data.title === title && e.ts >= lastOpened.ts,
      );
      if (!finishedSince && typeof title === 'string') currentlyReading = title;
    }

    return { booksFinished, minutesThisWeek, storiesCreated, lastComprehensionScorePct, currentlyReading };
  },
};
