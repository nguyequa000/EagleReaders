import {
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  writeBatch,
  type CollectionReference,
  type DocumentReference,
} from 'firebase/firestore';

import { auth, db } from '../firebase';
import { changesOf, noChanges, type ChangeSource } from './firestoreChanges';
import { hashPin, newSalt } from './pinHash';

/**
 * One child on the account: a display name plus a 4-digit PIN, stored as a
 * salted SHA-256 hash at `parents/{uid}/children/{childId}`. Same fields as
 * the Flutter app's ChildProfile.
 */
export type ChildProfile = {
  id: string;
  name: string;
  pinHash: string;
  pinSalt: string;
  emoji: string;
};

export async function childWithPin(id: string, name: string, pin: string): Promise<ChildProfile> {
  const pinSalt = newSalt();
  return { id, name, pinHash: await hashPin(pin, pinSalt), pinSalt, emoji: '🧒' };
}

export async function verifyChildPin(child: ChildProfile, pin: string): Promise<boolean> {
  return (await hashPin(pin, child.pinSalt)) === child.pinHash;
}

function fromMap(id: string, map: Record<string, any>): ChildProfile {
  return {
    id,
    name: typeof map.name === 'string' ? map.name : '',
    pinHash: typeof map.pinHash === 'string' ? map.pinHash : '',
    pinSalt: typeof map.pinSalt === 'string' ? map.pinSalt : '',
    emoji: typeof map.emoji === 'string' ? map.emoji : '🧒',
  };
}

export function parentRef(): DocumentReference | null {
  const uid = auth.currentUser?.uid;
  return uid ? doc(db, 'parents', uid) : null;
}

export function requireParent(what: string): DocumentReference {
  const parent = parentRef();
  if (!parent) throw new Error(`Cannot ${what} while signed out.`);
  return parent;
}

export function childRef(childId: string): DocumentReference | null {
  const parent = parentRef();
  return parent ? doc(parent, 'children', childId) : null;
}

function childrenCollection(): CollectionReference | null {
  const parent = parentRef();
  return parent ? collection(parent, 'children') : null;
}

export const ChildProfileStore = {
  /** All children on the account, oldest first; empty when signed out. */
  async load(): Promise<ChildProfile[]> {
    const children = childrenCollection();
    if (!children) return [];
    const snapshot = await getDocs(query(children, orderBy('sortOrder')));
    return snapshot.docs.map((d) => fromMap(d.id, d.data()));
  },

  changes(): ChangeSource {
    const children = childrenCollection();
    return children ? changesOf(children) : noChanges;
  },

  /**
   * Replaces the stored set with [profiles]: writes each one and deletes any
   * child no longer in the list, with that child's activity, coins and
   * stories (Firestore does not cascade deletes).
   */
  async save(profiles: ChildProfile[]): Promise<void> {
    const children = childrenCollection();
    if (!children) throw new Error('Cannot save child profiles while signed out.');
    const keep = new Set(profiles.map((p) => p.id));
    const existing = await getDocs(children);
    for (const d of existing.docs) {
      if (keep.has(d.id)) continue;
      for (const name of ['activity', 'coinLedger', 'stories']) {
        await deleteSubcollection(d.ref, name);
      }
    }
    const batch = writeBatch(db);
    for (const d of existing.docs) {
      if (!keep.has(d.id)) batch.delete(d.ref);
    }
    profiles.forEach((p, i) => {
      batch.set(
        doc(children, p.id),
        { name: p.name, pinHash: p.pinHash, pinSalt: p.pinSalt, emoji: p.emoji, sortOrder: i },
        { merge: true },
      );
    });
    await batch.commit();
  },
};

async function deleteSubcollection(child: DocumentReference, name: string) {
  const events = (await getDocs(collection(child, name))).docs;
  const chunk = 450;
  for (let i = 0; i < events.length; i += chunk) {
    const batch = writeBatch(db);
    for (const e of events.slice(i, i + chunk)) batch.delete(e.ref);
    await batch.commit();
  }
}
