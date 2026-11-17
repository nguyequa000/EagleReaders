import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  where,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction,
} from 'firebase/firestore';

import { db } from '../firebase';
import type { ActivityEvent } from './activity';
import { childRef, parentRef, type ChildProfile } from './childProfiles';
import { changesOf, mergeChanges, noChanges, type ChangeSource } from './firestoreChanges';

/**
 * Coin ledger and balance (CR #2), the same shape as the Flutter app:
 *
 *   parents/{uid}/children/{childId}                  coinBalance (int)
 *   parents/{uid}/children/{childId}/coinLedger/{id}
 *     type earn | redeem | refund, amount (signed), balanceAfter,
 *     reason quiz | story | reward, title, rewardId, status, redeemId, ts,
 *     resolvedAt
 *
 * Every row is written in the same transaction as the balance it produces.
 */
export type CoinTransaction = {
  id: string;
  type: string;
  amount: number;
  balanceAfter: number;
  reason: string;
  title: string;
  rewardId: string | null;
  status: string | null;
  redeemId: string | null;
  ts: number;
  resolvedAt: number | null;
};

export type PendingRedemption = { childId: string; childName: string; transaction: CoinTransaction };

/** A redemption that cannot go ahead; the message is written for the child. */
export class CoinError extends Error {}

export const COINS_PER_QUIZ = 5;
export const COINS_PER_STORY = 5;

function txFromMap(id: string, map: Record<string, any>): CoinTransaction {
  const num = (v: unknown, d = 0) => (typeof v === 'number' ? Math.trunc(v) : d);
  const str = (v: unknown) => (typeof v === 'string' ? v : null);
  return {
    id,
    type: str(map.type) ?? 'earn',
    amount: num(map.amount),
    balanceAfter: num(map.balanceAfter),
    reason: str(map.reason) ?? '',
    title: str(map.title) ?? '',
    rewardId: str(map.rewardId),
    status: str(map.status),
    redeemId: str(map.redeemId),
    ts: num(map.ts),
    resolvedAt: typeof map.resolvedAt === 'number' ? Math.trunc(map.resolvedAt) : null,
  };
}

export const isPending = (t: CoinTransaction) => t.type === 'redeem' && t.status === 'pending';
export const costOf = (t: CoinTransaction) => Math.abs(t.amount);

/** This row as an activity-feed entry, for the parent dashboard. */
export function txToActivity(t: CoinTransaction): ActivityEvent {
  return {
    type: t.type === 'redeem' ? 'reward_redeemed' : t.type === 'refund' ? 'coins_refunded' : 'coins_earned',
    ts: t.ts,
    data: { title: t.title, coins: Math.abs(t.amount), reason: t.reason },
  };
}

const balanceOf = (snap: DocumentSnapshot) => {
  const v = snap.data()?.coinBalance;
  return typeof v === 'number' ? Math.trunc(v) : 0;
};

function writeBalance(tx: Transaction, snap: DocumentSnapshot, balance: number) {
  if (snap.exists()) tx.update(snap.ref, { coinBalance: balance });
  else tx.set(snap.ref, { coinBalance: balance });
}

function requireChild(childId: string): DocumentReference {
  const child = childRef(childId);
  if (!child) throw new Error('Cannot change coins while signed out.');
  return child;
}

export const CoinService = {
  /** Adds coins and returns how many were awarded; 0 when signed out. */
  async earn(childId: string, reason: string, title: string, amount: number): Promise<number> {
    const child = childRef(childId);
    if (!child || amount <= 0) return 0;
    const row = doc(collection(child, 'coinLedger'));
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(child);
      const balance = balanceOf(snap) + amount;
      tx.set(row, { type: 'earn', amount, balanceAfter: balance, reason, title, ts: Date.now() });
      writeBalance(tx, snap, balance);
    });
    return amount;
  },

  awardQuiz: (childId: string, bookTitle: string) =>
    CoinService.earn(childId, 'quiz', bookTitle, COINS_PER_QUIZ),

  awardStory: (childId: string, storyTitle: string) =>
    CoinService.earn(childId, 'story', storyTitle, COINS_PER_STORY),

  changes(childId: string): ChangeSource {
    const child = childRef(childId);
    if (!child) return noChanges;
    return mergeChanges([changesOf(child), changesOf(collection(child, 'coinLedger'))]);
  },

  async balance(childId: string): Promise<number> {
    const child = childRef(childId);
    if (!child) return 0;
    return balanceOf(await getDoc(child));
  },

  /**
   * Spends coins on [rewardId]. The reward's cost and active flag are read
   * inside the transaction, so a stale catalog cannot buy at the old price.
   */
  async redeem(childId: string, rewardId: string): Promise<CoinTransaction> {
    const child = requireChild(childId);
    const rewardRef = doc(parentRef()!, 'rewards', rewardId);
    const row = doc(collection(child, 'coinLedger'));
    return runTransaction(db, async (tx) => {
      const rewardSnap = await tx.get(rewardRef);
      const childSnap = await tx.get(child);
      const reward = rewardSnap.data();
      const unavailable = "That reward isn't available any more.";
      if (!reward || reward.active === false) throw new CoinError(unavailable);
      const cost = typeof reward.coinCost === 'number' ? Math.trunc(reward.coinCost) : 0;
      const title = typeof reward.title === 'string' ? reward.title : '';
      const balance = balanceOf(childSnap);
      if (cost <= 0) throw new CoinError(unavailable);
      if (balance < cost) {
        const short = cost - balance;
        throw new CoinError(`You need ${short} more ${short === 1 ? 'coin' : 'coins'} for that one.`);
      }
      const data = {
        type: 'redeem',
        amount: -cost,
        balanceAfter: balance - cost,
        reason: 'reward',
        title,
        rewardId,
        status: 'pending',
        ts: Date.now(),
      };
      tx.set(row, data);
      writeBalance(tx, childSnap, balance - cost);
      return txFromMap(row.id, data);
    });
  },

  /** The parent has handed the reward over. */
  async markGiven(childId: string, transactionId: string): Promise<void> {
    const row = doc(requireChild(childId), 'coinLedger', transactionId);
    await runTransaction(db, async (tx) => {
      const current = txFromMap(transactionId, (await tx.get(row)).data() ?? {});
      if (!isPending(current)) throw new CoinError('This request has already been handled.');
      tx.update(row, { status: 'given', resolvedAt: Date.now() });
    });
  },

  /** The parent turned the request down: the coins go back as a refund row. */
  async decline(childId: string, transactionId: string): Promise<void> {
    const child = requireChild(childId);
    const row = doc(child, 'coinLedger', transactionId);
    const refund = doc(collection(child, 'coinLedger'));
    await runTransaction(db, async (tx) => {
      const current = txFromMap(transactionId, (await tx.get(row)).data() ?? {});
      const childSnap = await tx.get(child);
      const balance = balanceOf(childSnap);
      if (!isPending(current)) throw new CoinError('This request has already been handled.');
      const now = Date.now();
      tx.update(row, { status: 'declined', resolvedAt: now });
      tx.set(refund, {
        type: 'refund',
        amount: costOf(current),
        balanceAfter: balance + costOf(current),
        reason: 'reward',
        title: current.title,
        rewardId: current.rewardId,
        redeemId: transactionId,
        ts: now,
      });
      writeBalance(tx, childSnap, balance + costOf(current));
    });
  },

  async ledger(childId: string): Promise<CoinTransaction[]> {
    const child = childRef(childId);
    if (!child) return [];
    const snap = await getDocs(query(collection(child, 'coinLedger'), orderBy('ts')));
    return snap.docs.map((d) => txFromMap(d.id, d.data()));
  },

  /** The child's redemptions, newest first. */
  async redemptions(childId: string): Promise<CoinTransaction[]> {
    const child = childRef(childId);
    if (!child) return [];
    const snap = await getDocs(query(collection(child, 'coinLedger'), where('type', '==', 'redeem')));
    return snap.docs.map((d) => txFromMap(d.id, d.data())).sort((a, b) => b.ts - a.ts);
  },

  /**
   * Live list of pending redemptions across [children], oldest first. Emits
   * once every child's listener has reported, then on every change.
   */
  watchPending(children: ChildProfile[], onPending: (list: PendingRedemption[]) => void): () => void {
    const byChild = new Map<string, PendingRedemption[]>();
    const refs = children
      .map((c) => ({ child: c, ref: childRef(c.id) }))
      .filter((x): x is { child: ChildProfile; ref: DocumentReference } => !!x.ref);
    if (refs.length === 0) {
      onPending([]);
      return () => {};
    }
    const emit = () => {
      if (byChild.size < refs.length) return;
      const all = [...byChild.values()].flat().sort((a, b) => a.transaction.ts - b.transaction.ts);
      onPending(all);
    };
    const stops = refs.map(({ child, ref }) =>
      onSnapshot(
        query(collection(ref, 'coinLedger'), where('type', '==', 'redeem'), where('status', '==', 'pending')),
        (snap) => {
          byChild.set(
            child.id,
            snap.docs.map((d) => ({
              childId: child.id,
              childName: child.name,
              transaction: txFromMap(d.id, d.data()),
            })),
          );
          emit();
        },
        () => {},
      ),
    );
    return () => stops.forEach((stop) => stop());
  },
};
