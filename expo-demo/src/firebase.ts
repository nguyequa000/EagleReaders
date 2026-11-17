import AsyncStorage from '@react-native-async-storage/async-storage';
import { initializeApp } from 'firebase/app';
import { getReactNativePersistence, initializeAuth } from 'firebase/auth';
import { initializeFirestore } from 'firebase/firestore';

/**
 * The same Firebase project the Flutter app uses (its `web` options in
 * lib/services/firebase_options.dart), so logins and Gemini are real.
 *
 * What keeps this demo away from the main app's families is in
 * services/demoAccount.ts, not here.
 */
const firebaseConfig = {
  apiKey: 'AIzaSyBw7kItoiNcSwQJg55XH_0-D23r5DFOL30',
  appId: '1:850624934951:web:07b64f9c6dff3aa2bf0a02',
  messagingSenderId: '850624934951',
  projectId: 'story-sprout-test-project',
  authDomain: 'story-sprout-test-project.firebaseapp.com',
  storageBucket: 'story-sprout-test-project.firebasestorage.app',
};

export const app = initializeApp(firebaseConfig);

// Keeps the sign-in across app restarts, like Firebase Auth does on Flutter.
export const auth = initializeAuth(app, {
  persistence: getReactNativePersistence(AsyncStorage),
});

// Long polling is detected automatically; React Native's networking does not
// always support Firestore's default streaming transport.
export const db = initializeFirestore(app, {
  experimentalAutoDetectLongPolling: true,
});
