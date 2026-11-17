import * as Crypto from 'expo-crypto';

/**
 * Salted SHA-256 PIN hashing, byte for byte the same as the Flutter app's
 * `ChildProfile.hashPin` (hex digest of "salt:pin") and `newSalt` (16 random
 * bytes, base64url with padding), so either app can check a PIN the other set.
 */
export async function hashPin(pin: string, salt: string): Promise<string> {
  const digest = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, `${salt}:${pin}`);
  return digest.toLowerCase();
}

export function newSalt(): string {
  return base64Url(Crypto.getRandomBytes(16));
}

export async function pinFields(pin: string): Promise<{ pinHash: string; pinSalt: string }> {
  const pinSalt = newSalt();
  return { pinHash: await hashPin(pin, pinSalt), pinSalt };
}

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

function base64Url(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const a = bytes[i];
    const b = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const c = i + 2 < bytes.length ? bytes[i + 2] : 0;
    const n = (a << 16) | (b << 8) | c;
    out += ALPHABET[(n >> 18) & 63] + ALPHABET[(n >> 12) & 63];
    out += i + 1 < bytes.length ? ALPHABET[(n >> 6) & 63] : '=';
    out += i + 2 < bytes.length ? ALPHABET[n & 63] : '=';
  }
  return out;
}

export const PIN_SHAPE = /^\d{4}$/;
