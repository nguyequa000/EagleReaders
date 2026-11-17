import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * What this device remembers about signing in: whether to skip the login
 * screen next time, and the email to fill in when it does not. Never a
 * password or a PIN.
 */
const KEEP = 'session.keepSignedIn';
const EMAIL = 'session.email';

export const SessionPrefs = {
  async keepSignedIn(): Promise<boolean> {
    try {
      const value = await AsyncStorage.getItem(KEEP);
      return value == null ? true : value === 'true';
    } catch {
      return true;
    }
  },

  async rememberedEmail(): Promise<string | null> {
    try {
      return await AsyncStorage.getItem(EMAIL);
    } catch {
      return null;
    }
  },

  async save(keepSignedIn: boolean, email: string): Promise<void> {
    try {
      await AsyncStorage.multiSet([
        [KEEP, String(keepSignedIn)],
        [EMAIL, email],
      ]);
    } catch {
      // Only means the choice does not survive a restart.
    }
  },
};
