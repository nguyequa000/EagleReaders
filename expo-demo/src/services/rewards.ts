import {
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  type CollectionReference,
} from 'firebase/firestore';

import { parentRef } from './childProfiles';
import { changesOf, noChanges, type ChangeSource } from './firestoreChanges';

/**
 * A reward a parent defines for their children to redeem coins against (CR
 * #2), at `parents/{uid}/rewards/{rewardId}`. Coins have no real-money value.
 */
export type Reward = {
  id: string;
  title: string;
  description: string;
  coinCost: number;
  /** Retired rewards stay so past redemptions still resolve to a title. */
  active: boolean;
};

/** Thrown when a reward fails validation; the message is for the parent. */
export class RewardValidationError extends Error {}

export const MAX_COIN_COST = 10000;

function rewardsCollection(): CollectionReference | null {
  const parent = parentRef();
  return parent ? collection(parent, 'rewards') : null;
}

function requireCollection(): CollectionReference {
  const c = rewardsCollection();
  if (!c) throw new Error('Cannot change rewards while signed out.');
  return c;
}

function validate(title: string, coinCost: number) {
  if (!title) throw new RewardValidationError('Give the reward a name.');
  if (coinCost <= 0) throw new RewardValidationError('Cost must be at least 1 coin.');
  if (coinCost > MAX_COIN_COST) {
    throw new RewardValidationError(`Cost must be ${MAX_COIN_COST} coins or fewer.`);
  }
}

export const RewardStore = {
  changes(): ChangeSource {
    const c = rewardsCollection();
    return c ? changesOf(c) : noChanges;
  },

  /** The catalog, cheapest first. */
  async load(activeOnly = false): Promise<Reward[]> {
    const c = rewardsCollection();
    if (!c) return [];
    const snap = await getDocs(query(c, orderBy('coinCost')));
    const rewards = snap.docs.map((d) => {
      const m = d.data();
      return {
        id: d.id,
        title: typeof m.title === 'string' ? m.title : '',
        description: typeof m.description === 'string' ? m.description : '',
        coinCost: typeof m.coinCost === 'number' ? Math.trunc(m.coinCost) : 0,
        active: typeof m.active === 'boolean' ? m.active : true,
      };
    });
    return activeOnly ? rewards.filter((r) => r.active) : rewards;
  },

  async create(title: string, coinCost: number, description = ''): Promise<void> {
    const cleanTitle = title.trim();
    validate(cleanTitle, coinCost);
    await setDoc(doc(requireCollection()), {
      title: cleanTitle,
      description: description.trim(),
      coinCost,
      active: true,
      createdAt: serverTimestamp(),
    });
  },

  async update(id: string, title: string, coinCost: number, description = ''): Promise<void> {
    const cleanTitle = title.trim();
    validate(cleanTitle, coinCost);
    await setDoc(
      doc(requireCollection(), id),
      { title: cleanTitle, description: description.trim(), coinCost },
      { merge: true },
    );
  },

  /** Retires or restores a reward; never a delete, so old redemptions resolve. */
  async setActive(id: string, active: boolean): Promise<void> {
    await setDoc(doc(requireCollection(), id), { active }, { merge: true });
  },
};
