import { doc, getDoc } from 'firebase/firestore';

import { db } from '../firebase';

/**
 * Keeps the Expo demo away from the families made in the main Story Sprout
 * app.
 *
 * Everything the app stores lives under `parents/{uid}` (firestore.rules lets
 * each parent touch only their own), so the boundary is the account itself:
 * an account registered in this demo has this tag on its parent document, and
 * the demo refuses to sign in to any account without it. That way it can
 * never read or change the main app's children, stories, coins or rewards,
 * and the shared rules need no change.
 */
export const DEMO_TAG = 'expo-demo';

export const notDemoMessage =
  'This account belongs to the main Story Sprout app, so the demo leaves it ' +
  'alone to keep its data safe. Tap "New here? Register" to make a demo account.';

export type DemoCheck = 'demo' | 'not-demo' | 'unreachable';

/** Whether [uid]'s parent document carries the demo tag. */
export async function checkDemoAccount(uid: string): Promise<DemoCheck> {
  try {
    const snap = await getDoc(doc(db, 'parents', uid));
    return snap.data()?.createdBy === DEMO_TAG ? 'demo' : 'not-demo';
  } catch {
    return 'unreachable';
  }
}
