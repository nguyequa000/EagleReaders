import { createUserWithEmailAndPassword, deleteUser, onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { doc, serverTimestamp, setDoc } from 'firebase/firestore';
import React, { useEffect, useState } from 'react';
import { Image, KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, View } from 'react-native';

import { PaperBackground } from '../components/PaperBackground';
import {
  CenterSpinner,
  ErrorNote,
  Icon,
  PromptTag,
  StickerChoiceCard,
  StickerEmoji,
  StickerHeader,
  StickerPromptPage,
  StickerTextField,
  StoryButton,
  ThemeSticker,
} from '../components/sticker';
import { auth, db } from '../firebase';
import { useNav } from '../nav/Navigator';
import { checkDemoAccount, DEMO_TAG, notDemoMessage } from '../services/demoAccount';
import { ParentPin } from '../services/parentPin';
import { pinFields } from '../services/pinHash';
import { SessionPrefs } from '../services/sessionPrefs';
import { usePalette } from '../theme/ThemeProvider';
import { body, outlineWidthThin } from '../theme/palette';
import { ChildSelectorScreen, ChildSetupScreen, ParentPinScreen } from './family';

const codeOf = (e: unknown) => String((e as any)?.code ?? '').replace(/^auth\//, '');

/**
 * The app's first screen: decides whether this device is still signed in.
 * "Keep me signed in" decides whether launching skips the login screen; the
 * parent or child PIN is still asked for either way. A session for an account
 * that isn't a demo account is ended (see services/demoAccount.ts).
 */
export function AuthGate() {
  const palette = usePalette();
  const nav = useNav();

  useEffect(() => {
    let done = false;
    const stop = onAuthStateChanged(auth, async (user) => {
      if (done) return;
      done = true;
      stop();
      let notice: string | undefined;
      if (user) {
        if (await SessionPrefs.keepSignedIn()) {
          const check = await checkDemoAccount(user.uid);
          if (check === 'demo') {
            nav.replace(<ParentOrChildScreen />);
            return;
          }
          if (check === 'not-demo') notice = notDemoMessage;
        }
        await signOut(auth).catch(() => {});
      }
      nav.replace(<LoginScreen notice={notice} />);
    });
    return () => {
      done = true;
      stop();
    };
  }, [nav]);

  return (
    <PaperBackground>
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
        <StickerEmoji emoji="🌱" color={palette.tintGreen} size={104} />
        <View style={{ height: 28 }} />
        <CenterSpinnerInline />
      </View>
    </PaperBackground>
  );
}

function CenterSpinnerInline() {
  return (
    <View style={{ height: 40 }}>
      <CenterSpinner />
    </View>
  );
}

function loginMessage(code: string): string {
  switch (code) {
    case 'invalid-email':
      return "That doesn't look like a valid email.";
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'network-request-failed':
      return 'No connection. Check your network and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait and try again.';
    default:
      return 'Sign-in failed. Please try again.';
  }
}

export function LoginScreen({ notice }: { notice?: string }) {
  const palette = usePalette();
  const nav = useNav();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [keepSignedIn, setKeepSignedIn] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(notice ?? null);

  useEffect(() => {
    (async () => {
      const remembered = await SessionPrefs.rememberedEmail();
      const keep = await SessionPrefs.keepSignedIn();
      setEmail((current) => (current ? current : remembered ?? ''));
      setKeepSignedIn(keep);
    })();
  }, []);

  const login = async () => {
    const trimmed = email.trim();
    if (!trimmed || !password) {
      setError('Enter your email and password.');
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const cred = await signInWithEmailAndPassword(auth, trimmed, password);
      // Only accounts made in this demo; the main app's families stay untouched.
      const check = await checkDemoAccount(cred.user.uid);
      if (check !== 'demo') {
        await signOut(auth).catch(() => {});
        setError(
          check === 'not-demo'
            ? notDemoMessage
            : "We couldn't check this account. Check your connection and try again.",
        );
        return;
      }
      await SessionPrefs.save(keepSignedIn, trimmed);
      nav.replace(<ParentOrChildScreen />);
    } catch (e) {
      setError(loginMessage(codeOf(e)));
    } finally {
      setLoading(false);
    }
  };

  return (
    <PaperBackground>
      <StickerHeader title="Story Sprout" trailing={<ThemeSticker />} forParent />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView
          contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: 24, paddingBottom: 28 }}
          keyboardShouldPersistTaps="handled"
        >
          <View style={{ alignItems: 'center' }}>
            <Image
              source={require('../../assets/images/storysprout_logo.png')}
              style={{ width: 220, height: 160 }}
              resizeMode="contain"
            />
            <View style={{ height: 20 }} />
            <PromptTag text="Welcome Back!" size={26} />
          </View>
          <View style={{ height: 32 }} />
          <StickerTextField
            value={email}
            onChangeText={setEmail}
            placeholder="Email"
            icon="email"
            keyboardType="email-address"
          />
          <View style={{ height: 16 }} />
          <StickerTextField
            value={password}
            onChangeText={setPassword}
            placeholder="Password"
            icon="lock"
            secure
            onSubmit={login}
          />
          <Pressable
            onPress={() => !loading && setKeepSignedIn(!keepSignedIn)}
            accessibilityRole="checkbox"
            accessibilityState={{ checked: keepSignedIn }}
            style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 14 }}
          >
            <View
              style={{
                width: 24,
                height: 24,
                borderRadius: 6,
                borderWidth: outlineWidthThin,
                borderColor: palette.outline,
                backgroundColor: keepSignedIn ? palette.action : 'transparent',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {keepSignedIn && <Icon name="check" size={17} color={palette.onAction} />}
            </View>
            <Text style={[body(15, palette.ink, 600), { marginLeft: 12 }]}>Keep me signed in</Text>
          </Pressable>
          {error ? <ErrorNote message={error} /> : null}
          <View style={{ height: 24 }} />
          <StoryButton label={loading ? 'Logging in…' : 'Log In'} onPress={loading ? null : login} />
          <View style={{ height: 16 }} />
          <StoryButton
            label="New here? Register"
            filled={false}
            showArrow={false}
            onPress={() => nav.push(<RegistrationScreen />)}
          />
          <Text style={[body(13, palette.inkMuted, 400, 1.4), { textAlign: 'center', marginTop: 18 }]}>
            Demo app: it only opens accounts registered here, so families in the main Story Sprout
            app are never changed.
          </Text>
        </ScrollView>
      </KeyboardAvoidingView>
    </PaperBackground>
  );
}

function registerMessage(code: string): string {
  switch (code) {
    case 'email-already-in-use':
      return 'An account with that email already exists.';
    case 'weak-password':
      return 'Please choose a stronger password (6+ characters).';
    case 'invalid-email':
      return "That doesn't look like a valid email.";
    case 'operation-not-allowed':
      return 'Email sign-up is not enabled.';
    case 'network-request-failed':
      return 'No connection. Check your network and try again.';
    default:
      return 'Registration failed. Please try again.';
  }
}

export function RegistrationScreen() {
  const palette = usePalette();
  const nav = useNav();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [pin, setPin] = useState('');
  const [pinConfirm, setPinConfirm] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const register = async () => {
    const trimmed = email.trim();
    if (!trimmed) return setError('Enter your email.');
    if (password.length < 6) return setError('Password must be at least 6 characters.');
    if (!ParentPin.isValid(pin)) return setError('Choose a 4-digit parent PIN.');
    if (pinConfirm !== pin) return setError("The two PINs don't match.");
    setLoading(true);
    setError(null);
    try {
      const cred = await createUserWithEmailAndPassword(auth, trimmed, password);
      try {
        await setDoc(doc(db, 'parents', cred.user.uid), {
          email: cred.user.email,
          role: 'parent',
          createdAt: serverTimestamp(),
          // Marks this as a demo account; see services/demoAccount.ts.
          createdBy: DEMO_TAG,
          ...(await pinFields(pin)),
        });
      } catch {
        // Roll back so the parent can retry cleanly.
        await deleteUser(cred.user).catch(() => {});
        setError('Could not finish setting up your account. Please try again.');
        return;
      }
      await SessionPrefs.save(true, trimmed);
      nav.resetTo(<ChildSetupScreen />);
    } catch (e) {
      setError(registerMessage(codeOf(e)));
    } finally {
      setLoading(false);
    }
  };

  return (
    <StickerPromptPage title="Register" emoji="🌱" emojiTint={palette.tintGreen} prompt="Create an Account" forParent>
      <StickerTextField value={email} onChangeText={setEmail} placeholder="Email" icon="email" keyboardType="email-address" />
      <View style={{ height: 16 }} />
      <StickerTextField value={password} onChangeText={setPassword} placeholder="Password" icon="lock" secure />
      <View style={{ height: 24 }} />
      <Text style={body(15, palette.inkMuted)}>
        Choose a 4-digit parent PIN. You will use it to open the parent side, so children can only
        reach their own.
      </Text>
      <View style={{ height: 12 }} />
      <StickerTextField
        value={pin}
        onChangeText={(t) => setPin(t.replace(/\D/g, ''))}
        placeholder="Parent PIN"
        icon="pin"
        secure
        keyboardType="number-pad"
        maxLength={4}
      />
      <View style={{ height: 16 }} />
      <StickerTextField
        value={pinConfirm}
        onChangeText={(t) => setPinConfirm(t.replace(/\D/g, ''))}
        placeholder="Parent PIN again"
        icon="pin"
        secure
        keyboardType="number-pad"
        maxLength={4}
      />
      {error ? (
        <View style={{ marginTop: 16 }}>
          <ErrorNote message={error} />
        </View>
      ) : null}
      <View style={{ height: 24 }} />
      <StoryButton label={loading ? 'Registering…' : 'Register'} onPress={loading ? null : register} />
    </StickerPromptPage>
  );
}

/** "Who is reading today?" — the first screen once signed in. */
export function ParentOrChildScreen() {
  const palette = usePalette();
  const nav = useNav();
  return (
    <StickerPromptPage
      title="Story Sprout"
      emoji="🌱"
      emojiTint={palette.tintGreen}
      prompt="Who is reading today?"
      allowBack={false}
      forParent
    >
      <StickerChoiceCard emoji="👨‍👩‍👧" label="Parent" tint={palette.tintBlue} onPress={() => nav.push(<ParentPinScreen />)} />
      <View style={{ height: 20 }} />
      <StickerChoiceCard emoji="🧒" label="Child" tint={palette.tintYellow} onPress={() => nav.push(<ChildSelectorScreen />)} />
    </StickerPromptPage>
  );
}
