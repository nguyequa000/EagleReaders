import { getDoc, setDoc } from 'firebase/firestore';

import { requireParent } from './childProfiles';
import { hashPin, PIN_SHAPE, pinFields } from './pinHash';

/**
 * The parent's 4-digit PIN, kept as a salted hash beside the other fields on
 * `parents/{uid}` (`pinHash`, `pinSalt`). The plain PIN is never stored.
 */
export const ParentPin = {
  isValid: (pin: string) => PIN_SHAPE.test(pin),

  async stored(): Promise<{ hash: string; salt: string } | null> {
    const data = (await getDoc(requireParent('read the PIN'))).data();
    const hash = data?.pinHash;
    const salt = data?.pinSalt;
    if (typeof hash !== 'string' || typeof salt !== 'string') return null;
    return { hash, salt };
  },

  async isSet(): Promise<boolean> {
    return (await ParentPin.stored()) != null;
  },

  async verify(pin: string): Promise<boolean> {
    const stored = await ParentPin.stored();
    if (!stored) return false;
    return (await hashPin(pin, stored.salt)) === stored.hash;
  },

  async set(pin: string): Promise<void> {
    if (!ParentPin.isValid(pin)) throw new Error('not 4 digits');
    await setDoc(requireParent('set the PIN'), await pinFields(pin), { merge: true });
  },
};
