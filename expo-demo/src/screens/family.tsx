import React, { useCallback, useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';

import {
  CenterSpinner,
  ErrorNote,
  OptionRow,
  SheetPanel,
  StickerCard,
  StickerChoiceCard,
  StickerDialog,
  StickerEmoji,
  StickerHeader,
  StickerPage,
  StickerPill,
  StickerPinPage,
  StickerPromptPage,
  StickerTextField,
  StoryButton,
  ThemeSticker,
} from '../components/sticker';
import { PaperBackground } from '../components/PaperBackground';
import { useNav } from '../nav/Navigator';
import { ChildProfileStore, childWithPin, verifyChildPin, type ChildProfile } from '../services/childProfiles';
import { useLiveRefresh } from '../services/firestoreChanges';
import { ParentPin } from '../services/parentPin';
import { usePalette } from '../theme/ThemeProvider';
import { body, display, tintForIndex } from '../theme/palette';
import { ChildDashboardScreen } from './childDashboard';
import { ParentDashboardScreen } from './parent';

export function useMounted() {
  const mounted = React.useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  return mounted;
}

export function ChildSelectorScreen() {
  const palette = usePalette();
  const nav = useNav();
  const [children, setChildren] = useState<ChildProfile[] | null>(null);

  const load = useCallback(async () => {
    try {
      setChildren(await ChildProfileStore.load());
    } catch {
      setChildren([]);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);
  // A child added on another device appears without leaving this screen.
  useLiveRefresh(() => [ChildProfileStore.changes()], load);

  if (children && children.length === 0) {
    return (
      <StickerPromptPage
        title="Who are you?"
        emoji="🌱"
        emojiTint={palette.tintGreen}
        prompt="No child profiles yet."
        caption="Ask a parent to add them."
      />
    );
  }
  return (
    <StickerPromptPage title="Who are you?" emoji="👋" emojiTint={palette.tintBlue} prompt="Pick your name!">
      {children == null ? (
        <CenterSpinner />
      ) : (
        children.map((child, i) => (
          <View key={child.id} style={{ marginTop: i > 0 ? 20 : 0 }}>
            <StickerChoiceCard
              emoji={child.emoji}
              label={child.name}
              tint={tintForIndex(palette, i + 1)}
              onPress={() => nav.push(<ChildPinScreen child={child} />)}
            />
          </View>
        ))
      )}
    </StickerPromptPage>
  );
}

export function ChildPinScreen({ child }: { child: ChildProfile }) {
  const palette = usePalette();
  const nav = useNav();
  const [pin, setPin] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    if (await verifyChildPin(child, pin)) {
      nav.replace(<ChildDashboardScreen childId={child.id} childName={child.name} />);
    } else {
      setError('Incorrect PIN. Try again.');
    }
  };

  return (
    <StickerPinPage
      title={`Hi ${child.name}!`}
      emoji="🔑"
      emojiTint={palette.tintBlue}
      prompt={`Enter your PIN, ${child.name}!`}
      value={pin}
      onChangeText={(t) => {
        setPin(t);
        setError(null);
      }}
      error={error}
      buttonLabel="Let's Go! 🚀"
      onSubmit={submit}
    />
  );
}

type PinMode = 'loading' | 'enter' | 'create' | 'confirm';

/**
 * The parent's way in: the PIN they chose at registration. An account with
 * no PIN is asked to create one here, typed twice.
 */
export function ParentPinScreen() {
  const palette = usePalette();
  const nav = useNav();
  const mounted = useMounted();
  const [pin, setPin] = useState('');
  const [mode, setMode] = useState<PinMode>('loading');
  const [error, setError] = useState<string | null>(null);
  const [first, setFirst] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    (async () => {
      let isSet = true;
      try {
        isSet = await ParentPin.isSet();
      } catch {
        // Can't tell; ask for the PIN; a wrong guess just says so.
      }
      if (mounted.current) setMode(isSet ? 'enter' : 'create');
    })();
  }, [mounted]);

  const openDashboard = () => nav.replace(<ParentDashboardScreen />);

  const submit = async () => {
    if (busy) return;
    switch (mode) {
      case 'loading':
        return;
      case 'enter': {
        setBusy(true);
        let ok = false;
        try {
          ok = await ParentPin.verify(pin);
        } catch {
          ok = false;
        }
        setBusy(false);
        if (ok) openDashboard();
        else {
          setPin('');
          setError('Incorrect PIN. Try again.');
        }
        return;
      }
      case 'create':
        if (!ParentPin.isValid(pin)) return setError('Choose 4 digits.');
        setFirst(pin);
        setPin('');
        setMode('confirm');
        setError(null);
        return;
      case 'confirm':
        if (pin !== first) {
          setPin('');
          setFirst(null);
          setMode('create');
          setError("Those didn't match. Start again.");
          return;
        }
        setBusy(true);
        try {
          await ParentPin.set(pin);
        } catch {
          setBusy(false);
          setError("Couldn't save your PIN. Check your connection.");
          return;
        }
        openDashboard();
    }
  };

  if (mode === 'loading') {
    return (
      <PaperBackground>
        <StickerHeader title="Parent Login" showBack forParent trailing={<ThemeSticker />} />
        <CenterSpinner />
      </PaperBackground>
    );
  }
  const [prompt, button] =
    mode === 'create' ? ['Create a parent PIN', 'Next'] : mode === 'confirm' ? ['Type it again', 'Save PIN'] : ['Enter your PIN', 'Enter'];
  return (
    <StickerPinPage
      title="Parent Login"
      emoji="👨‍👩‍👧"
      emojiTint={palette.tintBlue}
      prompt={prompt}
      value={pin}
      onChangeText={(t) => {
        setPin(t);
        if (error) setError(null);
      }}
      error={error}
      buttonLabel={button}
      onSubmit={submit}
      forParent
    />
  );
}

const MAX_CHILDREN = 6;

/**
 * Shown once, right after a parent creates their account: how many children,
 * and a name and 4-digit PIN for each.
 */
export function ChildSetupScreen() {
  const palette = usePalette();
  const nav = useNav();
  const [names, setNames] = useState<string[]>(['']);
  const [pins, setPins] = useState<string[]>(['']);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const setCount = (n: number) => {
    setNames((list) => Array.from({ length: n }, (_, i) => list[i] ?? ''));
    setPins((list) => Array.from({ length: n }, (_, i) => list[i] ?? ''));
    setError(null);
  };

  const chooseCount = async () => {
    const n = await nav.showSheet<number>(
      <SheetPanel>
        <Text style={[display(20, palette.ink, 700), { marginBottom: 8 }]}>How many children?</Text>
        {Array.from({ length: MAX_CHILDREN }, (_, i) => i + 1).map((n) => (
          <OptionRow key={n} label={`${n}`} selected={n === names.length} onPress={() => nav.pop(n)} />
        ))}
      </SheetPanel>,
    );
    if (n) setCount(n);
  };

  const save = async () => {
    const trimmed = names.map((n) => n.trim());
    if (trimmed.some((n) => !n) || pins.some((p) => !/^\d{4}$/.test(p))) {
      setError('Give each child a name and a 4-digit PIN.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const now = Date.now() * 1000;
      const profiles = await Promise.all(trimmed.map((name, i) => childWithPin(`${now}_${i}`, name, pins[i])));
      await ChildProfileStore.save(profiles);
    } catch {
      setSaving(false);
      setError('Could not save. Check your connection and try again.');
      return;
    }
    nav.resetTo(<ParentDashboardScreen />);
  };

  return (
    <StickerPage title="Add Your Children" forParent allowBack={false}>
      <ScrollView contentContainerStyle={{ padding: 20, paddingRight: 24, paddingBottom: 28 }} keyboardShouldPersistTaps="handled">
        <Text style={body(15, palette.inkMuted)}>Set up a profile and PIN for each child on this account.</Text>
        <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 18, marginBottom: 18 }}>
          <Text style={[display(18, palette.ink, 700), { flex: 1 }]}>How many children?</Text>
          <StickerPill onPress={saving ? undefined : chooseCount}>
            <Text style={display(18, palette.ink, 600)}>{names.length} ▾</Text>
          </StickerPill>
        </View>
        {names.map((name, i) => (
          <View key={i} style={{ marginBottom: 16 }}>
            <StickerCard padding={16}>
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 14 }}>
                <StickerEmoji emoji="🧒" color={i % 2 === 0 ? palette.tintYellow : palette.tintBlue} size={40} />
                <Text style={[display(18, palette.ink, 700), { marginLeft: 12 }]}>Child {i + 1}</Text>
              </View>
              <StickerTextField
                label="Name"
                value={name}
                autoCapitalize="words"
                shadow={false}
                onChangeText={(t) => {
                  setNames((list) => list.map((v, j) => (j === i ? t : v)));
                  if (error) setError(null);
                }}
              />
              <View style={{ height: 12 }} />
              <StickerTextField
                label="4-digit PIN"
                value={pins[i]}
                secure
                keyboardType="number-pad"
                maxLength={4}
                shadow={false}
                onChangeText={(t) => {
                  setPins((list) => list.map((v, j) => (j === i ? t.replace(/\D/g, '') : v)));
                  if (error) setError(null);
                }}
              />
            </StickerCard>
          </View>
        ))}
        {error ? (
          <View style={{ marginBottom: 8 }}>
            <ErrorNote message={error} />
          </View>
        ) : null}
        <View style={{ height: 8 }} />
        <StoryButton label={saving ? 'Saving…' : 'Done'} onPress={saving ? null : save} />
      </ScrollView>
    </StickerPage>
  );
}

/** The parent PIN, to lift today's limit. Pops with true when it's right. */
export function GrownUpPinDialog() {
  const nav = useNav();
  const [pin, setPin] = useState('');
  const [error, setError] = useState<string | null>(null);
  const submit = async () => {
    let ok = false;
    try {
      ok = await ParentPin.verify(pin);
    } catch {
      ok = false;
    }
    if (ok) nav.pop(true);
    else setError('Incorrect PIN. Try again.');
  };
  return (
    <StickerDialog
      title="Grown-up unlock"
      actions={[
        { label: 'Cancel', onPress: () => nav.pop(false) },
        { label: 'Unlock', onPress: submit },
      ]}
    >
      <StickerTextField
        label="Parent PIN"
        value={pin}
        onChangeText={(t) => setPin(t.replace(/\D/g, ''))}
        secure
        keyboardType="number-pad"
        maxLength={4}
        autoFocus
        error={error}
        onSubmit={submit}
        shadow={false}
      />
    </StickerDialog>
  );
}

/** A small "tap to choose" pill that opens a picker sheet. */
export function PickerPill<T>({
  value,
  options,
  label,
  onChange,
  title,
}: {
  value: T;
  options: { value: T; label: string }[];
  label: string;
  onChange: (value: T) => void;
  title: string;
}) {
  const palette = usePalette();
  const nav = useNav();
  const open = async () => {
    const picked = await nav.showSheet<{ value: T }>(
      <SheetPanel>
        <Text style={[display(20, palette.ink, 700), { marginBottom: 8 }]}>{title}</Text>
        {options.map((o) => (
          <OptionRow key={o.label} label={o.label} selected={o.value === value} onPress={() => nav.pop({ value: o.value })} />
        ))}
      </SheetPanel>,
    );
    if (picked) onChange(picked.value);
  };
  return (
    <Pressable onPress={open} accessibilityRole="button" style={{ paddingVertical: 6 }}>
      <Text style={display(16, palette.ink, 600)}>{label} ▾</Text>
    </Pressable>
  );
}
