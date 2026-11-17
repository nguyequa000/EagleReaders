import {
  EmailAuthProvider,
  reauthenticateWithCredential,
  signOut,
  updatePassword,
  verifyBeforeUpdateEmail,
} from 'firebase/auth';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, Switch, Text, View } from 'react-native';

import {
  CenterSpinner,
  ErrorNote,
  Icon,
  SectionTitle,
  SheetPanel,
  StickerCard,
  StickerDialog,
  StickerEmoji,
  StickerIconButton,
  StickerIconDisc,
  StickerPage,
  StickerRow,
  StickerTextField,
  StoryButton,
  type IconName,
} from '../components/sticker';
import { useToast } from '../components/Toast';
import { auth } from '../firebase';
import { useNav } from '../nav/Navigator';
import { ActivityService, describeEvent, type ActivityEvent, type ChildActivityStats } from '../services/activity';
import { ChildProfileStore, type ChildProfile } from '../services/childProfiles';
import {
  CoinError,
  CoinService,
  costOf,
  isPending,
  txToActivity,
  type CoinTransaction,
  type PendingRedemption,
} from '../services/coins';
import {
  defaultAiSettings,
  defaultChildRules,
  FamilySettings,
  type AiSettings,
  type ChildRules,
} from '../services/familySettings';
import { useLiveRefresh } from '../services/firestoreChanges';
import { AGE_BANDS, ageBandInfo } from '../services/readerAudience';
import { RewardStore, RewardValidationError, type Reward } from '../services/rewards';
import { usePalette } from '../theme/ThemeProvider';
import { body, display, radiusButton, tintForIndex } from '../theme/palette';
import { LoginScreen } from './auth';
import { BookShelfScreen, ChildShelfScreen } from './books';
import { PickerPill, useMounted } from './family';

/**
 * Parent-facing dashboard: family reading stats and the recent activity feed,
 * the children, books and rewards. A live listener on pending redemptions
 * drives the bell's badge and a banner when a child redeems.
 */
export function ParentDashboardScreen() {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const mounted = useMounted();
  const [children, setChildren] = useState<ChildProfile[] | null>(null);
  const [balances, setBalances] = useState<Record<string, number>>({});
  const [pending, setPending] = useState<PendingRedemption[]>([]);
  const [activity, setActivity] = useState<[string, ActivityEvent][]>([]);
  const [stats, setStats] = useState({ books: 0, minutes: 0, stories: 0 });
  const [statsByChild, setStatsByChild] = useState<Record<string, ChildActivityStats>>({});
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [name, setName] = useState<string | null>(null);
  const seen = useRef(new Set<string>());
  const primed = useRef(false);

  const load = useCallback(async () => {
    let list: ChildProfile[] = [];
    try {
      list = await ChildProfileStore.load();
    } catch {
      list = [];
    }
    const feed: [string, ActivityEvent][] = [];
    const byChild: Record<string, ChildActivityStats> = {};
    const coins: Record<string, number> = {};
    let books = 0;
    let minutes = 0;
    let stories = 0;
    for (const child of list) {
      let events: ActivityEvent[] = [];
      try {
        events = await ActivityService.getEvents(child.id);
      } catch {
        events = [];
      }
      const s = ActivityService.statsFrom(events);
      byChild[child.id] = s;
      events.forEach((e) => feed.push([child.name, e]));
      try {
        coins[child.id] = await CoinService.balance(child.id);
        (await CoinService.ledger(child.id)).forEach((t) => feed.push([child.name, txToActivity(t)]));
      } catch {
        // Coins are a nice-to-have on this screen.
      }
      books += s.booksFinished;
      minutes += s.minutesThisWeek;
      stories += s.storiesCreated;
    }
    feed.sort((a, b) => a[1].ts - b[1].ts);
    let greeting: string | null = null;
    try {
      greeting = await FamilySettings.loadGreetingName();
    } catch {
      greeting = null;
    }
    if (!mounted.current) return;
    setName(greeting);
    setChildren(list);
    setStatsByChild(byChild);
    setBalances(coins);
    setActivity(feed);
    setStats({ books, minutes, stories });
    setLoading(false);
  }, [mounted]);

  useEffect(() => {
    load();
  }, [load]);

  const openRequests = useCallback(async () => {
    await nav.push(<RewardRequestsScreen />);
    load();
  }, [load, nav]);

  const childKey = (children ?? []).map((c) => c.id).join(',');

  // Pending redemptions: the first emission only primes what's been seen;
  // anything after it is a fresh redemption and gets a banner.
  useEffect(() => {
    if (!children) return;
    primed.current = false;
    return CoinService.watchPending(children, (list) => {
      const fresh = list.filter((p) => !seen.current.has(p.transaction.id));
      fresh.forEach((p) => seen.current.add(p.transaction.id));
      setPending(list);
      if (primed.current && fresh.length > 0) {
        const p = fresh[fresh.length - 1];
        toast.show(`${p.childName} redeemed "${p.transaction.title}" (${costOf(p.transaction)} coins)`, {
          action: { label: 'View', onPress: openRequests },
        });
        load();
      }
      primed.current = true;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [childKey]);

  useLiveRefresh(
    () => [
      ChildProfileStore.changes(),
      FamilySettings.changes(),
      ...(children ?? []).flatMap((c) => [ActivityService.changes(c.id), CoinService.changes(c.id)]),
    ],
    load,
    childKey,
  );

  return (
    <StickerPage
      title="Parent Dashboard"
      forParent
      allowBack={false}
      actions={
        <View>
          <StickerIconButton icon="notifications" label="Reward requests" onPress={openRequests} />
          {pending.length > 0 && (
            <View
              style={{
                position: 'absolute',
                top: 0,
                right: 0,
                minWidth: 20,
                height: 20,
                borderRadius: 10,
                paddingHorizontal: 5,
                backgroundColor: palette.action,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Text style={display(12, palette.onAction, 700)}>{pending.length}</Text>
            </View>
          )}
        </View>
      }
    >
      {loading ? (
        <CenterSpinner />
      ) : (
        <ScrollView
          contentContainerStyle={{ padding: 18, paddingRight: 22, paddingBottom: 28 }}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={async () => {
                setRefreshing(true);
                await load();
                setRefreshing(false);
              }}
            />
          }
        >
          <ProfileHeader
            name={name}
            action={
              <Pressable
                accessibilityLabel="Settings"
                onPress={async () => {
                  await nav.push(<ParentSettingsScreen />);
                  load();
                }}
                style={{ padding: 10 }}
              >
                <Icon name="settings" color={palette.ink} />
              </Pressable>
            }
          />
          <View style={{ height: 24 }} />
          <SectionTitle text="Reading Stats" />
          <View style={{ flexDirection: 'row', gap: 10 }}>
            <StatCard icon="menu-book" color={palette.tintBlue} label="Books Read" value={stats.books} />
            <StatCard icon="schedule" color={palette.tintCoral} label={'Minutes Read\nThis Week'} value={stats.minutes} />
            <StatCard icon="star-outline" color={palette.tintMagenta} label={'Stories\nCreated'} value={stats.stories} />
          </View>
          <View style={{ height: 24 }} />
          <SectionTitle text="Child Profiles" />
          {children && children.length === 0 ? <ActivityItem text="No child profiles yet." /> : null}
          {(children ?? []).map((child, i) => (
            <View key={child.id} style={{ marginBottom: 10 }}>
              <StickerCard radius={radiusButton} depth={3} padding={{ paddingHorizontal: 14, paddingVertical: 12 }}>
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <StickerEmoji emoji={child.emoji} color={i % 2 === 0 ? palette.tintYellow : palette.tintBlue} size={46} />
                  <View style={{ flex: 1, marginLeft: 14 }}>
                    <Text style={display(18, palette.ink, 700)}>{child.name}</Text>
                    {balances[child.id] != null && (
                      <Text style={body(13, palette.ink, 700)}>
                        🪙 {balances[child.id]} {balances[child.id] === 1 ? 'coin' : 'coins'}
                      </Text>
                    )}
                    {statsByChild[child.id]?.currentlyReading ? (
                      <Text numberOfLines={1} style={body(13, palette.inkMuted)}>
                        Reading: {statsByChild[child.id].currentlyReading}
                      </Text>
                    ) : null}
                  </View>
                  <StoryButton
                    label="View"
                    showArrow={false}
                    small
                    style={{ width: 92, marginLeft: 8 }}
                    onPress={() => nav.push(<ChildProfileScreen childId={child.id} childName={child.name} />)}
                  />
                </View>
              </StickerCard>
            </View>
          ))}
          <View style={{ height: 14 }} />
          <SectionTitle text="Books" />
          <StickerRow
            leading={<StickerIconDisc icon="local-library" color={palette.tintGreen} />}
            title="Manage Shelf"
            subtitle="Import books and choose who reads them"
            onPress={() => nav.push(<BookShelfScreen />)}
          />
          <View style={{ height: 24 }} />
          <SectionTitle text="Rewards" />
          <StickerRow
            leading={<StickerIconDisc icon="notifications" color={pending.length > 0 ? palette.tintCoral : palette.tintYellow} />}
            title="Reward Requests"
            subtitle={pending.length === 0 ? 'No requests waiting' : `${pending.length} waiting for you to hand over`}
            onPress={openRequests}
          />
          <View style={{ height: 10 }} />
          <StickerRow
            leading={<StickerIconDisc icon="redeem" color={palette.tintMagenta} />}
            title="Manage Rewards"
            subtitle="Set what your children can spend coins on"
            onPress={() => nav.push(<RewardsManagerScreen />)}
          />
          <View style={{ height: 24 }} />
          <SectionTitle text="Family's Recent Activity" />
          {activity.length === 0 ? (
            <ActivityItem text="No activity yet — start reading to see it here." />
          ) : (
            [...activity]
              .reverse()
              .slice(0, 12)
              .map(([childName, event], i) => (
                <View key={i} style={{ marginBottom: 10 }}>
                  <ActivityItem text={describeEvent(event, childName)} type={event.type} />
                </View>
              ))
          )}
        </ScrollView>
      )}
    </StickerPage>
  );
}

function ProfileHeader({ name, action }: { name: string | null; action: React.ReactNode }) {
  const palette = usePalette();
  return (
    <StickerCard padding={{ paddingLeft: 16, paddingRight: 8, paddingVertical: 14 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <StickerIconDisc icon="people-alt" color={palette.tintMagenta} size={56} />
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text numberOfLines={1} style={display(20, palette.ink, 700)}>
            {name ? `Hello, ${name}` : 'Hello!'}
          </Text>
          <Text style={body(13, palette.inkMuted)}>Parent Account</Text>
        </View>
        {action}
      </View>
    </StickerCard>
  );
}

function StatCard({ icon, color, label, value }: { icon: IconName; color: string; label: string; value: number }) {
  const palette = usePalette();
  return (
    <View style={{ flex: 1 }}>
      <StickerCard color={color} radius={radiusButton} depth={3} padding={{ paddingVertical: 12, paddingHorizontal: 6 }}>
        <View style={{ alignItems: 'center' }}>
          <Icon name={icon} size={22} color={palette.ink} />
          <Text style={[display(26, palette.ink, 700), { marginTop: 4 }]}>{value}</Text>
          <Text style={[body(12, palette.ink, 400, 1.2), { textAlign: 'center', marginTop: 2 }]}>{label}</Text>
        </View>
      </StickerCard>
    </View>
  );
}

function ActivityItem({ text, type }: { text: string; type?: string }) {
  const palette = usePalette();
  const [icon, tint]: [IconName, string] =
    type == null
      ? ['info-outline', palette.surface]
      : type === 'story_created'
        ? ['edit', palette.tintMagenta]
        : type === 'comprehension_result'
          ? ['quiz', palette.tintGreen]
          : ['coins_earned', 'reward_redeemed', 'coins_refunded'].includes(type)
            ? ['redeem', palette.tintYellow]
            : ['menu-book', palette.tintBlue];
  return (
    <StickerCard radius={radiusButton} depth={3} padding={{ paddingHorizontal: 12, paddingVertical: 10 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <StickerIconDisc icon={icon} color={tint} size={34} />
        <Text style={[body(14, palette.ink), { flex: 1, marginLeft: 12 }]}>{text}</Text>
      </View>
    </StickerCard>
  );
}

function authMessage(e: unknown): string {
  switch (String((e as any)?.code ?? '').replace(/^auth\//, '')) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'user-mismatch':
      return 'Your current password is incorrect.';
    case 'invalid-email':
      return "That doesn't look like a valid email.";
    case 'email-already-in-use':
      return 'Another account already uses that email.';
    case 'weak-password':
      return 'Use at least 6 characters for the new password.';
    case 'requires-recent-login':
      return 'Please sign out, sign back in, and try again.';
    case 'network-request-failed':
      return 'No connection. Check your network and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/** Proves it's still the parent before an account change. */
async function reauthenticate(password: string) {
  const user = auth.currentUser;
  if (!user?.email) throw Object.assign(new Error('requires-recent-login'), { code: 'auth/requires-recent-login' });
  await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, password));
}

export function ParentSettingsScreen() {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const [ai, setAi] = useState<AiSettings>(defaultAiSettings);
  const [name, setName] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    let settings = defaultAiSettings;
    let greeting: string | null = null;
    try {
      settings = await FamilySettings.load();
      greeting = await FamilySettings.loadGreetingName();
    } catch {
      greeting = auth.currentUser?.email?.split('@')[0] ?? null;
    }
    setAi(settings);
    setName(greeting);
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);
  useLiveRefresh(() => [FamilySettings.changes()], load);

  /** Flips a switch straight away and saves it; puts it back if that fails. */
  const update = async (next: AiSettings) => {
    const previous = ai;
    setAi(next);
    try {
      await FamilySettings.save(next);
    } catch {
      setAi(previous);
      toast.show("We couldn't save that setting. Check your connection.");
    }
  };

  const editName = async () => {
    const next = await nav.showDialog<string>(<NameDialog initial={name ?? ''} />);
    if (next == null) return;
    try {
      await FamilySettings.saveDisplayName(next);
      setName(next.trim());
    } catch {
      toast.show("We couldn't save your name. Try again.");
    }
  };

  const toggle = (label: string, subtitle: string, key: keyof AiSettings) => (
    <View style={{ marginBottom: 10 }}>
      <StickerCard radius={radiusButton} depth={3} padding={{ paddingLeft: 16, paddingRight: 10, paddingVertical: 10 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={{ flex: 1 }}>
            <Text style={display(16, palette.ink, 700)}>{label}</Text>
            <Text style={body(13, palette.inkMuted, 400, 1.35)}>{subtitle}</Text>
          </View>
          <Switch
            value={ai[key]}
            disabled={loading}
            onValueChange={(v) => update({ ...ai, [key]: v })}
            trackColor={{ true: palette.action, false: palette.track }}
            ios_backgroundColor={palette.track}
          />
        </View>
      </StickerCard>
    </View>
  );

  return (
    <StickerPage title="Parent Settings" forParent>
      <ScrollView contentContainerStyle={{ padding: 18, paddingRight: 22, paddingBottom: 28 }}>
        <ProfileHeader
          name={name}
          action={
            <Pressable onPress={editName} style={{ padding: 10 }}>
              <Text style={display(16, palette.ink, 700)}>Edit</Text>
            </Pressable>
          }
        />
        <View style={{ height: 24 }} />
        <SectionTitle text="Security Settings" />
        <StickerRow
          leading={<StickerIconDisc icon="email" color={palette.tintBlue} />}
          title="Change Email"
          onPress={async () => {
            const sentTo = await nav.showDialog<string>(<ChangeEmailDialog />);
            if (sentTo) toast.show(`Check ${sentTo} for a link to finish changing your email.`);
          }}
        />
        <View style={{ height: 10 }} />
        <StickerRow
          leading={<StickerIconDisc icon="lock-outline" color={palette.tintBlue} />}
          title="Change Password"
          onPress={async () => {
            if (await nav.showDialog<boolean>(<ChangePasswordDialog />)) toast.show('Your password has been changed.');
          }}
        />
        <View style={{ height: 24 }} />
        <SectionTitle text="AI Settings" />
        {toggle('AI story writing', "Sprout writes stories from your child's picks", 'aiStories')}
        {toggle('AI reading quizzes', 'Short quizzes after chapters, books and stories', 'aiQuizzes')}
        {toggle("Sprout's writing ideas", 'Idea questions while your child writes a story', 'sproutIdeas')}
        <View style={{ height: 14 }} />
        <SectionTitle text="App Preferences" />
        {toggle('Read Aloud', 'Stories can be read out loud', 'readAloud')}
        {toggle('Reading Reminders', "A nudge on your child's home screen if they haven't read today", 'readingReminder')}
        <View style={{ height: 14 }} />
        <SectionTitle text="Content Settings" />
        <StickerRow
          leading={<StickerIconDisc icon="child-care" color={palette.tintYellow} />}
          title="Age Restrictions"
          trailing={<Text style={display(15, palette.ink, 700)}>Edit</Text>}
          onPress={() => nav.push(<ChildRulesScreen />)}
        />
        <View style={{ height: 10 }} />
        <StickerRow
          leading={<StickerIconDisc icon="timer" color={palette.tintYellow} />}
          title="Time Limit"
          trailing={<Text style={display(15, palette.ink, 700)}>Edit</Text>}
          onPress={() => nav.push(<ChildRulesScreen />)}
        />
        <View style={{ height: 28 }} />
        <StoryButton
          label="Sign Out"
          filled={false}
          showArrow={false}
          onPress={async () => {
            await signOut(auth).catch(() => {});
            nav.resetTo(<LoginScreen />);
          }}
        />
      </ScrollView>
    </StickerPage>
  );
}

function NameDialog({ initial }: { initial: string }) {
  const nav = useNav();
  const [name, setName] = useState(initial);
  return (
    <StickerDialog
      title="Your name"
      actions={[
        { label: 'Cancel', onPress: () => nav.pop() },
        { label: 'Save', onPress: name.trim() ? () => nav.pop(name) : null },
      ]}
    >
      <StickerTextField label="Name" value={name} onChangeText={setName} autoFocus maxLength={30} autoCapitalize="words" shadow={false} />
    </StickerDialog>
  );
}

function ChangeEmailDialog() {
  const nav = useNav();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    const next = email.trim();
    if (!next || !password) return setError('Enter the new email and your password.');
    if (next === auth.currentUser?.email) return setError("That's already your email.");
    setBusy(true);
    setError(null);
    try {
      await reauthenticate(password);
      // Firebase only switches the email once the link sent to it is opened.
      await verifyBeforeUpdateEmail(auth.currentUser!, next);
      nav.pop(next);
    } catch (e) {
      setBusy(false);
      setError(authMessage(e));
    }
  };
  return (
    <StickerDialog
      title="Change Email"
      actions={[
        { label: 'Cancel', onPress: busy ? null : () => nav.pop() },
        { label: 'Send link', onPress: busy ? null : submit, busy },
      ]}
    >
      <StickerTextField label="New email" value={email} onChangeText={setEmail} keyboardType="email-address" shadow={false} />
      <View style={{ height: 12 }} />
      <StickerTextField label="Current password" value={password} onChangeText={setPassword} secure shadow={false} />
      {error ? (
        <View style={{ marginTop: 12 }}>
          <ErrorNote message={error} />
        </View>
      ) : null}
    </StickerDialog>
  );
}

function ChangePasswordDialog() {
  const nav = useNav();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    if (!current || !next) return setError('Fill in every field.');
    if (next !== confirm) return setError("The new passwords don't match.");
    if (next.length < 6) return setError('Use at least 6 characters for the new password.');
    setBusy(true);
    setError(null);
    try {
      await reauthenticate(current);
      await updatePassword(auth.currentUser!, next);
      nav.pop(true);
    } catch (e) {
      setBusy(false);
      setError(authMessage(e));
    }
  };
  return (
    <StickerDialog
      title="Change Password"
      actions={[
        { label: 'Cancel', onPress: busy ? null : () => nav.pop() },
        { label: 'Change', onPress: busy ? null : submit, busy },
      ]}
    >
      <StickerTextField label="Current password" value={current} onChangeText={setCurrent} secure shadow={false} />
      <View style={{ height: 12 }} />
      <StickerTextField label="New password" value={next} onChangeText={setNext} secure shadow={false} />
      <View style={{ height: 12 }} />
      <StickerTextField label="Confirm new password" value={confirm} onChangeText={setConfirm} secure shadow={false} />
      {error ? (
        <View style={{ marginTop: 12 }}>
          <ErrorNote message={error} />
        </View>
      ) : null}
    </StickerDialog>
  );
}

const LIMITS: (number | null)[] = [15, 30, 45, 60, null];
const limitLabel = (m: number | null) => (m == null ? 'No limit' : m === 60 ? '1 hour' : `${m} minutes`);

/** Age Restrictions and Time Limit: each child's age band and daily limit. */
export function ChildRulesScreen() {
  const palette = usePalette();
  const toast = useToast();
  const [children, setChildren] = useState<ChildProfile[] | null>(null);
  const [rules, setRules] = useState<Record<string, ChildRules>>({});
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const list = await ChildProfileStore.load();
        const loaded: Record<string, ChildRules> = {};
        for (const c of list) loaded[c.id] = await FamilySettings.loadChild(c.id);
        setRules(loaded);
        setChildren(list);
      } catch {
        setError("We couldn't load your children. Try again.");
      }
    })();
  }, []);

  const save = async (child: ChildProfile, next: ChildRules) => {
    const previous = rules[child.id] ?? defaultChildRules;
    setRules((r) => ({ ...r, [child.id]: next }));
    try {
      await FamilySettings.saveChild(child.id, next);
    } catch {
      setRules((r) => ({ ...r, [child.id]: previous }));
      toast.show(`We couldn't save ${child.name}'s settings.`);
    }
  };

  const message = (text: string) => (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <Text style={[body(15, palette.ink), { textAlign: 'center' }]}>{text}</Text>
    </View>
  );

  return (
    <StickerPage title="Age & Time Limits" forParent>
      {error ? (
        message(error)
      ) : children == null ? (
        <CenterSpinner />
      ) : children.length === 0 ? (
        message('Add a child first.')
      ) : (
        <ScrollView contentContainerStyle={{ padding: 18, paddingRight: 22, paddingBottom: 28 }}>
          <StickerCard color={palette.tintGreen} padding={16}>
            <Text style={display(18, palette.ink, 700)}>What the ages mean</Text>
            <Text style={[body(15, palette.ink), { marginTop: 4 }]}>
              The age changes how Sprout writes stories and quiz questions for that child.
            </Text>
            {AGE_BANDS.map((band) => (
              <View key={band} style={{ marginTop: 10 }}>
                <Text style={body(15, palette.ink, 800)}>{ageBandInfo[band].label}</Text>
                <Text style={body(15, palette.ink)}>{ageBandInfo[band].summary}</Text>
              </View>
            ))}
          </StickerCard>
          <Text style={[body(15, palette.inkMuted), { marginVertical: 16 }]}>
            The daily limit counts today's reading time. When it's used up, reading and story making
            wait until tomorrow unless a grown-up unlocks them with the parent PIN.
          </Text>
          {children.map((child, i) => {
            const r = rules[child.id] ?? defaultChildRules;
            return (
              <View key={child.id} style={{ marginBottom: 16 }}>
                <StickerCard padding={{ paddingLeft: 16, paddingRight: 12, paddingVertical: 14 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <StickerEmoji emoji={child.emoji} color={i % 2 === 0 ? palette.tintYellow : palette.tintBlue} size={42} />
                    <Text style={[display(19, palette.ink, 700), { marginLeft: 12 }]}>{child.name}</Text>
                  </View>
                  <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 8 }}>
                    <Text style={[body(15, palette.ink, 700), { flex: 1 }]}>Age</Text>
                    <PickerPill
                      title={`${child.name}'s age`}
                      value={r.ageBand}
                      label={ageBandInfo[r.ageBand].label}
                      options={AGE_BANDS.map((b) => ({ value: b, label: ageBandInfo[b].label }))}
                      onChange={(ageBand) => save(child, { ...r, ageBand })}
                    />
                  </View>
                  <Text style={body(13, palette.inkMuted)}>{ageBandInfo[r.ageBand].summary}</Text>
                  <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 4 }}>
                    <Text style={[body(15, palette.ink, 700), { flex: 1 }]}>Daily reading limit</Text>
                    <PickerPill
                      title="Daily reading limit"
                      value={r.dailyLimitMinutes}
                      label={limitLabel(r.dailyLimitMinutes)}
                      options={LIMITS.map((m) => ({ value: m, label: limitLabel(m) }))}
                      onChange={(dailyLimitMinutes) => save(child, { ...r, dailyLimitMinutes })}
                    />
                  </View>
                </StickerCard>
              </View>
            );
          })}
        </ScrollView>
      )}
    </StickerPage>
  );
}

/** Parent-facing reward catalog: create rewards and set their coin cost. */
export function RewardsManagerScreen() {
  const palette = usePalette();
  const nav = useNav();
  const [rewards, setRewards] = useState<Reward[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setRewards(await RewardStore.load());
    } catch {
      setRewards([]);
    }
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  useLiveRefresh(() => [RewardStore.changes()], load);

  const openEditor = async (existing?: Reward) => {
    if (await nav.showSheet<boolean>(<RewardEditorSheet existing={existing} />)) load();
  };

  const toggleActive = async (reward: Reward) => {
    setError(null);
    try {
      await RewardStore.setActive(reward.id, !reward.active);
      load();
    } catch (e) {
      setError(`Could not update reward: ${String((e as Error)?.message ?? e)}`);
    }
  };

  return (
    <StickerPage title="Rewards" forParent>
      {rewards == null ? (
        <CenterSpinner />
      ) : (
        <ScrollView contentContainerStyle={{ padding: 18, paddingRight: 22, paddingBottom: 28 }}>
          <Text style={body(15, palette.inkMuted, 400, 1.4)}>
            Rewards your children can spend coins on. You decide what each one costs, and you hand
            it over yourself — coins have no cash value.
          </Text>
          <View style={{ height: 18 }} />
          <StoryButton label="New Reward" showArrow={false} onPress={() => openEditor()} />
          <View style={{ height: 22 }} />
          {error ? (
            <View style={{ marginBottom: 16 }}>
              <ErrorNote message={error} />
            </View>
          ) : null}
          {rewards.length === 0 ? (
            <StickerCard padding={24}>
              <View style={{ alignItems: 'center' }}>
                <StickerIconDisc icon="redeem" color={palette.tintMagenta} size={64} />
                <Text style={[display(18, palette.ink, 700), { marginTop: 14 }]}>No rewards yet</Text>
                <Text style={[body(15, palette.inkMuted), { textAlign: 'center', marginTop: 6 }]}>
                  Add one and it shows up on your child's screen straight away.
                </Text>
              </View>
            </StickerCard>
          ) : (
            rewards.map((reward, i) => (
              <View key={reward.id} style={{ marginBottom: 14 }}>
                <StickerCard
                  color={reward.active ? palette.surface : palette.ground}
                  radius={radiusButton}
                  depth={reward.active ? 3 : 0}
                  padding={{ paddingLeft: 14, paddingRight: 4, paddingVertical: 12 }}
                >
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <StickerIconDisc icon="redeem" color={reward.active ? tintForIndex(palette, i + 1) : palette.disabled} />
                    <View style={{ flex: 1, marginLeft: 14 }}>
                      <Text style={display(17, palette.ink, 700)}>{reward.title}</Text>
                      {reward.description ? <Text style={body(13, palette.inkMuted)}>{reward.description}</Text> : null}
                      <Text style={body(13, reward.active ? palette.ink : palette.inkMuted, 700)}>
                        {reward.active ? `${reward.coinCost} coins` : `${reward.coinCost} coins · hidden from children`}
                      </Text>
                    </View>
                    <Pressable accessibilityLabel="Edit" onPress={() => openEditor(reward)} style={{ padding: 10 }}>
                      <Icon name="edit" color={palette.ink} />
                    </Pressable>
                    <Pressable
                      accessibilityLabel={reward.active ? 'Retire' : 'Restore'}
                      onPress={() => toggleActive(reward)}
                      style={{ padding: 10 }}
                    >
                      <Icon name={reward.active ? 'visibility-off' : 'undo'} color={palette.ink} />
                    </Pressable>
                  </View>
                </StickerCard>
              </View>
            ))
          )}
        </ScrollView>
      )}
    </StickerPage>
  );
}

function RewardEditorSheet({ existing }: { existing?: Reward }) {
  const palette = usePalette();
  const nav = useNav();
  const [title, setTitle] = useState(existing?.title ?? '');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [cost, setCost] = useState(existing ? String(existing.coinCost) : '');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const save = async () => {
    setError(null);
    setSaving(true);
    const value = /^\d+$/.test(cost.trim()) ? parseInt(cost.trim(), 10) : NaN;
    if (Number.isNaN(value)) {
      setError('Enter the cost in whole coins.');
      setSaving(false);
      return;
    }
    try {
      if (existing) await RewardStore.update(existing.id, title, value, description);
      else await RewardStore.create(title, value, description);
      nav.pop(true);
    } catch (e) {
      setError(e instanceof RewardValidationError ? e.message : `Could not save: ${String((e as Error)?.message ?? e)}`);
      setSaving(false);
    }
  };

  return (
    <SheetPanel>
      <Text style={[display(22, palette.ink, 700), { marginBottom: 16 }]}>{existing ? 'Edit Reward' : 'New Reward'}</Text>
      <StickerTextField
        label="Reward"
        placeholder="Trip for ice cream"
        value={title}
        onChangeText={(t) => {
          setTitle(t);
          setError(null);
        }}
        shadow={false}
      />
      <View style={{ height: 14 }} />
      <StickerTextField label="Details (optional)" placeholder="Saturday afternoon" value={description} onChangeText={setDescription} shadow={false} />
      <View style={{ height: 14 }} />
      <StickerTextField
        label="Cost to redeem (coins)"
        value={cost}
        keyboardType="number-pad"
        onChangeText={(t) => {
          setCost(t);
          setError(null);
        }}
        shadow={false}
      />
      {error ? (
        <View style={{ marginTop: 14 }}>
          <ErrorNote message={error} />
        </View>
      ) : null}
      <View style={{ height: 20 }} />
      <StoryButton label={saving ? 'Saving...' : 'Save Reward'} showArrow={false} onPress={saving ? null : save} />
    </SheetPanel>
  );
}

type Request = { child: ChildProfile; tx: CoinTransaction };

const when = (ts: number) => {
  const d = new Date(ts);
  return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
};

/** Rewards the children have redeemed, waiting to be given or declined. */
export function RewardRequestsScreen() {
  const palette = usePalette();
  const nav = useNav();
  const [requests, setRequests] = useState<Request[] | null>(null);
  const [children, setChildren] = useState<ChildProfile[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<Set<string>>(new Set());

  const load = useCallback(async () => {
    const list: Request[] = [];
    try {
      const kids = await ChildProfileStore.load();
      setChildren(kids);
      for (const child of kids) {
        for (const tx of await CoinService.redemptions(child.id)) list.push({ child, tx });
      }
    } catch (e) {
      setError(`Could not load requests: ${String((e as Error)?.message ?? e)}`);
    }
    list.sort((a, b) => b.tx.ts - a.tx.ts);
    setRequests(list);
  }, []);

  useEffect(() => {
    load();
  }, [load]);
  const childKey = children.map((c) => c.id).join(',');
  useLiveRefresh(() => [ChildProfileStore.changes(), ...children.map((c) => CoinService.changes(c.id))], load, childKey);

  const resolve = async (request: Request, give: boolean) => {
    if (!give) {
      const confirmed = await nav.showDialog<boolean>(
        <StickerDialog
          title="Decline this request?"
          actions={[
            { label: 'Cancel', onPress: () => nav.pop(false) },
            { label: 'Decline', onPress: () => nav.pop(true) },
          ]}
        >
          <Text style={body(15, palette.ink)}>
            {request.child.name} gets their {costOf(request.tx)} coins back for "{request.tx.title}".
          </Text>
        </StickerDialog>,
      );
      if (!confirmed) return;
    }
    setError(null);
    setBusy((b) => new Set(b).add(request.tx.id));
    try {
      if (give) await CoinService.markGiven(request.child.id, request.tx.id);
      else await CoinService.decline(request.child.id, request.tx.id);
    } catch (e) {
      setError(e instanceof CoinError ? e.message : String((e as Error)?.message ?? e));
    }
    await load();
    setBusy((b) => {
      const next = new Set(b);
      next.delete(request.tx.id);
      return next;
    });
  };

  const pending = (requests ?? []).filter((r) => isPending(r.tx));
  const history = (requests ?? []).filter((r) => !isPending(r.tx));

  return (
    <StickerPage title="Reward Requests" forParent>
      {requests == null ? (
        <CenterSpinner />
      ) : (
        <ScrollView contentContainerStyle={{ padding: 18, paddingRight: 22, paddingBottom: 28 }}>
          {error ? (
            <View style={{ marginBottom: 16 }}>
              <ErrorNote message={error} />
            </View>
          ) : null}
          <SectionTitle text="Waiting for you" />
          {pending.length === 0 ? (
            <StickerCard radius={radiusButton} depth={3} padding={{ paddingHorizontal: 16, paddingVertical: 14 }}>
              <Text style={body(15, palette.inkMuted)}>No requests right now.</Text>
            </StickerCard>
          ) : (
            pending.map((r) => (
              <View key={r.tx.id} style={{ marginBottom: 16 }}>
                <StickerCard padding={16}>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <StickerEmoji emoji={r.child.emoji} color={palette.tintYellow} size={44} />
                    <View style={{ flex: 1, marginLeft: 12 }}>
                      <Text style={display(17, palette.ink, 700)}>
                        {r.child.name} redeemed "{r.tx.title}"
                      </Text>
                      <Text style={body(13, palette.inkMuted)}>
                        {costOf(r.tx)} coins · {when(r.tx.ts)}
                      </Text>
                    </View>
                  </View>
                  <View style={{ flexDirection: 'row', marginTop: 14, gap: 12 }}>
                    <StoryButton
                      label="Decline"
                      filled={false}
                      showArrow={false}
                      style={{ flex: 1 }}
                      onPress={busy.has(r.tx.id) ? null : () => resolve(r, false)}
                    />
                    <StoryButton
                      label="Mark as given"
                      showArrow={false}
                      style={{ flex: 2 }}
                      onPress={busy.has(r.tx.id) ? null : () => resolve(r, true)}
                    />
                  </View>
                </StickerCard>
              </View>
            ))
          )}
          {history.length > 0 && (
            <>
              <View style={{ height: 18 }} />
              <SectionTitle text="History" />
              {history.map((r) => {
                const given = r.tx.status === 'given';
                return (
                  <View key={r.tx.id} style={{ marginBottom: 10 }}>
                    <StickerRow
                      leading={<StickerIconDisc icon={given ? 'check' : 'undo'} color={given ? palette.tintGreen : palette.surface} size={38} />}
                      title={`${r.child.name}: ${r.tx.title}`}
                      subtitle={[given ? 'Given' : `Declined, ${costOf(r.tx)} coins refunded`, r.tx.resolvedAt ? when(r.tx.resolvedAt) : null]
                        .filter(Boolean)
                        .join(' · ')}
                      trailing={<Text style={display(15, palette.ink, 700)}>{costOf(r.tx)} 🪙</Text>}
                    />
                  </View>
                );
              })}
            </>
          )}
        </ScrollView>
      )}
    </StickerPage>
  );
}

/** Parent-facing view of one child's reading profile. */
export function ChildProfileScreen({ childId, childName }: { childId: string; childName: string }) {
  const palette = usePalette();
  const nav = useNav();
  const [events, setEvents] = useState<ActivityEvent[]>([]);
  const [stats, setStats] = useState<ChildActivityStats | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    let list: ActivityEvent[] = [];
    try {
      list = await ActivityService.getEvents(childId);
    } catch {
      list = [];
    }
    setEvents(list);
    setStats(ActivityService.statsFrom(list));
    setLoading(false);
  }, [childId]);
  useEffect(() => {
    load();
  }, [load]);
  useLiveRefresh(() => [ActivityService.changes(childId)], load);

  const tile = (icon: IconName, tint: string, label: string, value: string) => (
    <View style={{ marginBottom: 10 }}>
      <StickerRow
        leading={<StickerIconDisc icon={icon} color={tint} size={38} />}
        title={label}
        trailing={
          <Text numberOfLines={2} style={[display(16, palette.ink, 700), { maxWidth: 140, textAlign: 'right' }]}>
            {value}
          </Text>
        }
      />
    </View>
  );
  const score = stats?.lastComprehensionScorePct;

  return (
    <StickerPage title={`${childName}'s Profile`} forParent>
      {loading ? (
        <CenterSpinner />
      ) : (
        <ScrollView contentContainerStyle={{ padding: 18, paddingTop: 20, paddingRight: 22, paddingBottom: 28 }}>
          <View style={{ alignItems: 'center' }}>
            <StickerEmoji emoji="🧒" color={palette.tintYellow} size={88} />
            <Text style={[display(24, palette.ink, 700), { marginTop: 10 }]}>{childName}</Text>
          </View>
          <View style={{ height: 20 }} />
          <StickerRow
            leading={<StickerIconDisc icon="library-add" color={palette.tintGreen} />}
            title={`Choose ${childName}'s books`}
            subtitle="Pick books from the family shelf"
            onPress={() => nav.push(<ChildShelfScreen childId={childId} childName={childName} />)}
          />
          <View style={{ height: 24 }} />
          <SectionTitle text="Reading" />
          {tile('menu-book', palette.tintBlue, 'Books finished', `${stats?.booksFinished ?? 0}`)}
          {tile('timer', palette.tintCoral, 'Minutes read this week', `${stats?.minutesThisWeek ?? 0}`)}
          {tile('edit-note', palette.tintMagenta, 'Stories created', `${stats?.storiesCreated ?? 0}`)}
          {tile('quiz', palette.tintGreen, 'Last quiz score', score == null ? 'No quiz yet' : `${Math.round(score)}%`)}
          {tile('bookmark', palette.tintYellow, 'Currently reading', stats?.currentlyReading ?? 'Nothing right now')}
          <View style={{ height: 14 }} />
          <SectionTitle text="All Activity" />
          {events.length === 0 ? (
            <StickerRow leading={<StickerIconDisc icon="info-outline" color={palette.surface} size={34} />} title="No activity yet." />
          ) : (
            [...events].reverse().map((e, i) => (
              <View key={i} style={{ marginBottom: 10 }}>
                <StickerRow
                  leading={
                    <StickerIconDisc
                      icon={e.type === 'story_created' ? 'edit' : 'menu-book'}
                      color={e.type === 'story_created' ? palette.tintMagenta : palette.tintBlue}
                      size={34}
                    />
                  }
                  title={describeEvent(e, childName)}
                  subtitle={new Date(e.ts).toLocaleString([], { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}
                />
              </View>
            ))
          )}
        </ScrollView>
      )}
    </StickerPage>
  );
}
