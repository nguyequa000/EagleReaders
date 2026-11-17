import React, { useCallback, useEffect, useState } from 'react';
import { Image, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { PaperBackground } from '../components/PaperBackground';
import {
  Icon,
  SheetPanel,
  StickerCard,
  StickerHeader,
  StickerIconButton,
  StickerPill,
  StoryButton,
  ThemeSticker,
  type IconName,
} from '../components/sticker';
import { useToast } from '../components/Toast';
import { useNav } from '../nav/Navigator';
import { ActivityService, type ActivityEvent } from '../services/activity';
import { BookLibrary, type Book } from '../services/bookLibrary';
import { CoinService } from '../services/coins';
import {
  defaultAiSettings,
  defaultChildRules,
  FamilySettings,
  limitReached,
  minutesReadToday,
  readToday,
  type AiSettings,
  type ChildRules,
} from '../services/familySettings';
import { useLiveRefresh } from '../services/firestoreChanges';
import { ReaderAudience } from '../services/readerAudience';
import { questionFromJson, type ComprehensionQuestion } from '../services/storyGenerator';
import { byAi, DEFAULT_TITLE, StoryStore, type SavedStory, type StoredStory } from '../services/storyStore';
import { storyTitle, type StoryConfig } from '../story/model';
import { usePalette } from '../theme/ThemeProvider';
import { body, display, outlineWidth, outlineWidthThin, radiusButton, tintForIndex } from '../theme/palette';
import { GrownUpPinDialog, useMounted } from './family';
import { ReadingScreen } from './reader';
import { ChildRewardsScreen } from './rewardsChild';
import {
  AiStorySaver,
  MyStoryScreen,
  recordStoryCreated,
  StoryFlowScreen,
  StoryReaderScreen,
  StoryWriterScreen,
} from './story';

// Ready-made story ideas; tapping one writes a fresh story from it.
const STORY_PRESETS: { title: string; emoji: string; config: StoryConfig }[] = [
  {
    title: 'Dragon Adventure',
    emoji: '🐉',
    config: { hero: { character: 'monster' }, mood: 'Adventurous', setting: 'Forest', idea: 'A friendly dragon goes looking for a lost treasure.' },
  },
  {
    title: 'Space Explorer',
    emoji: '🚀',
    config: { hero: { character: 'explorer' }, mood: 'Adventurous', setting: 'Outer Space', idea: 'The explorer flies a rocket to visit a new planet.' },
  },
  {
    title: 'Magic Forest',
    emoji: '🌲',
    config: { hero: { character: 'friend' }, mood: 'Calm', setting: 'Forest', idea: 'Helping the forest animals get ready for winter.' },
  },
  {
    title: 'Ocean Quest',
    emoji: '🌊',
    config: { hero: { character: 'scout' }, mood: 'Funny', setting: 'Ocean', idea: 'Sailing off to find a singing sea turtle.' },
  },
];

const HOME_BOOKS = 4;

const settingEmoji = (s?: string | null) =>
  ({ Forest: '🌲', Ocean: '🌊', City: '🏙️', 'Outer Space': '🚀' } as Record<string, string>)[s ?? ''] ?? '📖';

const byRecent = (books: Book[]) =>
  [...books].sort((a, b) => (b.lastOpenedAt ?? b.addedAt) - (a.lastOpenedAt ?? a.addedAt));

export function ChildDashboardScreen({ childId, childName }: { childId: string; childName: string }) {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const mounted = useMounted();
  const [tab, setTab] = useState(0);
  const [coins, setCoins] = useState<number | null>(null);
  const [books, setBooks] = useState<Book[] | null>(null);
  const [stories, setStories] = useState<StoredStory[] | null>(null);
  const [ai, setAi] = useState<AiSettings>(defaultAiSettings);
  const [rules, setRules] = useState<ChildRules>(defaultChildRules);
  const [minutesToday, setMinutesToday] = useState(0);
  // Assumed until the activity loads, so no reminder flashes up first.
  const [readTodayFlag, setReadToday] = useState(true);

  const loadStories = useCallback(async () => {
    let list: StoredStory[] = [];
    try {
      list = await StoryStore.loadStories(childId);
    } catch {
      list = [];
    }
    if (mounted.current) setStories(list);
  }, [childId, mounted]);

  const loadBooks = useCallback(async () => {
    let list: Book[] = [];
    try {
      list = await BookLibrary.load(childId);
    } catch {
      list = [];
    }
    if (mounted.current) setBooks(byRecent(list));
  }, [childId, mounted]);

  const loadRules = useCallback(async () => {
    let settings: AiSettings;
    let childRules: ChildRules;
    let events: ActivityEvent[];
    try {
      settings = await FamilySettings.load();
      childRules = await FamilySettings.loadChild(childId);
      events = await ActivityService.getEvents(childId);
    } catch {
      return;
    }
    // Everything Gemini writes from here on is pitched at this child.
    ReaderAudience.current = childRules.ageBand;
    const now = new Date();
    if (!mounted.current) return;
    setAi(settings);
    setRules(childRules);
    setMinutesToday(minutesReadToday(events, now));
    setReadToday(readToday(events, now));
  }, [childId, mounted]);

  const loadBalance = useCallback(async () => {
    try {
      const value = await CoinService.balance(childId);
      if (mounted.current) setCoins(value);
    } catch {
      // Keep the last known balance.
    }
  }, [childId, mounted]);

  const refresh = useCallback(async () => {
    await Promise.all([loadBalance(), loadRules(), loadBooks(), loadStories()]);
  }, [loadBalance, loadBooks, loadRules, loadStories]);

  useEffect(() => {
    refresh();
  }, [refresh]);
  useLiveRefresh(
    () => [CoinService.changes(childId), FamilySettings.changes(childId), StoryStore.changes(childId)],
    refresh,
  );

  const locked = limitReached(rules, minutesToday, new Date());

  /** Opens [screen], then re-reads coins and reading time once it closes. */
  const open = async <T,>(screen: React.ReactElement) => {
    const result = await nav.push<T>(screen);
    await refresh();
    return result;
  };

  const unlock = async () => {
    const ok = await nav.showDialog<boolean>(<GrownUpPinDialog />);
    if (!ok) return;
    try {
      await FamilySettings.unlockToday(childId);
    } catch {
      toast.show("Couldn't unlock. Try again.");
      return;
    }
    await loadRules();
  };

  const showDoneForToday = async () => {
    const choice = await nav.showSheet<'unlock'>(<DoneForTodaySheet />);
    if (choice === 'unlock') unlock();
  };

  /** Opens [screen] unless today's time is used up. */
  const guarded = (screen: React.ReactElement) => (locked ? showDoneForToday() : open(screen));

  const createStory = () => guarded(<StoryFlowScreen childId={childId} childName={childName} />);
  const openRewards = () => open(<ChildRewardsScreen childId={childId} childName={childName} />);

  const resumeStory = async (story: StoredStory) => {
    if (locked) return showDoneForToday();
    if (byAi(story)) {
      const questions: ComprehensionQuestion[] = [];
      for (const q of story.questions) {
        try {
          questions.push(questionFromJson(q));
        } catch {
          // A damaged question is skipped.
        }
      }
      return open(
        <StoryReaderScreen
          config={story.config}
          childId={childId}
          childName={childName}
          initialStory={{ title: story.title, pages: story.pages, choices: story.choices, questions }}
          initialPage={story.page}
          initialChapters={story.chapters}
          onProgress={new AiStorySaver(childId, story.config, story.id).save}
        />,
      );
    }
    const saved = await nav.push<SavedStory>(
      <StoryWriterScreen config={story.config} childId={childId} showIdeas={ai.sproutIdeas} resume={story} />,
    );
    if (saved) {
      const typed = saved.title.trim();
      recordStoryCreated(toast, childId, !typed || typed === DEFAULT_TITLE ? storyTitle(story.config) : typed);
      await open(<MyStoryScreen title={saved.title} text={saved.text} />);
    } else {
      await refresh();
    }
  };

  const finished = (stories ?? []).filter((s) => s.completed).sort((a, b) => (b.completedAt ?? 0) - (a.completedAt ?? 0));
  const unfinished = (stories ?? []).filter((s) => !s.completed);
  const reading = (books ?? []).filter((b) => b.lastOpenedAt != null);
  const openBook = (book: Book) => guarded(<ReadingScreen childId={childId} childName={childName} book={book} />);

  const homeTab = (
    <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 24 }}>
      {locked ? (
        <Banner
          emoji="🌙"
          title="All done for today!"
          message={`You read for ${minutesToday} minutes. Great job! Come back tomorrow for more stories.`}
          action="Grown-up unlock"
          onAction={unlock}
        />
      ) : ai.readingReminder && !readTodayFlag ? (
        <Banner
          emoji="📚"
          title="You haven't read today"
          message="Let's read a story together!"
          action="Read now"
          onAction={() => setTab(1)}
        />
      ) : null}
      <SectionHeader title="Currently Reading" tint={1} />
      {books == null ? null : books.length === 0 ? (
        <NoBooks />
      ) : reading.length === 0 ? (
        <StickerCard padding={20}>
          <View style={{ alignItems: 'center' }}>
            <Text style={{ fontSize: 40 }}>📚</Text>
            <Text style={[display(18, palette.ink, 700), { marginTop: 8 }]}>Pick a book to start</Text>
            <Text style={[body(15, palette.inkMuted), { textAlign: 'center', marginTop: 4 }]}>
              Your books are waiting in My Library.
            </Text>
            <View style={{ height: 12, alignSelf: 'stretch' }} />
            <StoryButton label="Open My Library" onPress={() => setTab(1)} style={{ alignSelf: 'stretch' }} />
          </View>
        </StickerCard>
      ) : (
        <>
          <BookGrid books={reading.slice(0, HOME_BOOKS)} onOpen={openBook} />
          {books.length > Math.min(reading.length, HOME_BOOKS) && (
            <View style={{ alignItems: 'flex-end', marginTop: 8 }}>
              <StickerPill onPress={() => setTab(1)} color={palette.action}>
                <Text style={display(14, palette.onAction, 700)}>See all {books.length} books</Text>
              </StickerPill>
            </View>
          )}
        </>
      )}
      <View style={{ height: 24 }} />
      <SectionHeader title="My Stories" tint={2} />
      {stories && (
        <StoryRow>
          {finished.map((s, i) => (
            <StoryCard
              key={s.id}
              index={i}
              title={s.title}
              emoji={settingEmoji(s.config.setting)}
              caption={byAi(s) ? 'With Sprout' : 'By you'}
              onPress={() => open(<MyStoryScreen title={s.title} text={s.text} />)}
            />
          ))}
          {finished.length === 0 && <NewStoryCard onPress={createStory} />}
        </StoryRow>
      )}
      <View style={{ height: 24 }} />
      <SectionHeader title="Still Working On" tint={3} />
      {stories &&
        (unfinished.length === 0 ? (
          <Text style={body(15, palette.inkMuted)}>Stories you start but don't finish will wait for you here.</Text>
        ) : (
          <StoryRow>
            {unfinished.map((s, i) => (
              <StoryCard
                key={s.id}
                index={i}
                title={s.title}
                emoji={settingEmoji(s.config.setting)}
                caption={byAi(s) ? 'Keep reading' : 'Keep writing'}
                unfinished
                onPress={() => resumeStory(s)}
              />
            ))}
          </StoryRow>
        ))}
      {/* The ideas are written by AI, so they go when AI stories do. */}
      {ai.aiStories && (
        <>
          <View style={{ height: 24 }} />
          <SectionHeader title="Story Ideas" tint={4} />
          <Grid>
            {STORY_PRESETS.map((preset, i) => (
              <Card
                key={preset.title}
                index={i}
                tinted
                title={preset.title}
                emoji={preset.emoji}
                aspect={0.75}
                onPress={() =>
                  guarded(
                    <StoryReaderScreen
                      config={preset.config}
                      childId={childId}
                      childName={childName}
                      onProgress={new AiStorySaver(childId, preset.config).save}
                    />,
                  )
                }
              />
            ))}
          </Grid>
        </>
      )}
    </ScrollView>
  );

  const libraryTab = (
    <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 24 }}>
      <SectionHeader title="My Library" tint={1} />
      {books &&
        (books.length === 0 ? (
          <NoBooks />
        ) : (
          <BookGrid books={[...books].sort((a, b) => a.title.toLowerCase().localeCompare(b.title.toLowerCase()))} onOpen={openBook} />
        ))}
    </ScrollView>
  );

  return (
    <PaperBackground>
      <StickerHeader
        title={`Hi ${childName}! 🌱`}
        trailing={
          <>
            {coins != null && (
              <StickerPill onPress={openRewards}>
                <Text style={display(16, palette.ink, 700)}>🪙 {coins}</Text>
              </StickerPill>
            )}
            <StickerIconButton icon="redeem" label="My Rewards" onPress={openRewards} />
            <ThemeSticker />
          </>
        }
      />
      <View style={{ flex: 1 }}>
        <View style={{ flex: 1, display: tab === 0 ? 'flex' : 'none' }}>{homeTab}</View>
        <View style={{ flex: 1, display: tab === 1 ? 'flex' : 'none' }}>{libraryTab}</View>
      </View>
      <NavBar
        current={tab}
        onPress={(i) => {
          if (i === 2) createStory();
          else setTab(i);
        }}
      />
    </PaperBackground>
  );
}

function SectionHeader({ title, tint }: { title: string; tint: number }) {
  const palette = usePalette();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 12 }}>
      <StickerPill color={tintForIndex(palette, tint)}>
        <Text style={display(18, palette.ink, 700)}>{title}</Text>
      </StickerPill>
      <View style={{ flex: 1, height: outlineWidthThin, backgroundColor: palette.outline, borderRadius: 2, marginLeft: 12 }} />
    </View>
  );
}

function Grid({ children }: { children: React.ReactNode }) {
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 18, paddingRight: 4 }}>
      {children}
    </View>
  );
}

function BookGrid({ books, onOpen }: { books: Book[]; onOpen: (b: Book) => void }) {
  return (
    <Grid>
      {books.map((book, i) => (
        <Card
          key={book.id}
          index={i}
          title={book.title}
          emoji="📖"
          coverUri={book.coverUri}
          aspect={0.66}
          caption={book.chapter === 0 ? 'Ready to read' : `Chapter ${book.chapter} of ${book.chaptersTotal}`}
          onPress={() => onOpen(book)}
        />
      ))}
    </Grid>
  );
}

function Card({
  index,
  title,
  emoji,
  coverUri,
  caption,
  tinted,
  aspect,
  onPress,
}: {
  index: number;
  title: string;
  emoji: string;
  coverUri?: string | null;
  caption?: string;
  tinted?: boolean;
  aspect: number;
  onPress: () => void;
}) {
  const palette = usePalette();
  const [failed, setFailed] = useState(false);
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={title} style={{ width: '47%' }}>
      <StickerCard color={tinted ? tintForIndex(palette, index) : palette.surface} radius={radiusButton}>
        <View style={{ aspectRatio: aspect, alignItems: 'center', justifyContent: 'center' }}>
          {coverUri && !failed ? (
            <Image source={{ uri: coverUri }} style={{ width: '100%', height: '100%' }} resizeMode="cover" onError={() => setFailed(true)} />
          ) : (
            <Text style={{ fontSize: 48 }}>{emoji}</Text>
          )}
        </View>
      </StickerCard>
      <CardTitle title={title} caption={caption} />
    </Pressable>
  );
}

function CardTitle({ title, caption }: { title: string; caption?: string }) {
  const palette = usePalette();
  return (
    <View style={{ marginTop: 8 }}>
      <Text numberOfLines={1} style={[display(14, palette.ink, 700), { textAlign: 'center' }]}>
        {title}
      </Text>
      {caption ? (
        <Text numberOfLines={1} style={[body(12, palette.inkMuted, 600, 1.3), { textAlign: 'center' }]}>
          {caption}
        </Text>
      ) : null}
    </View>
  );
}

function StoryRow({ children }: { children: React.ReactNode }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ padding: 4, paddingBottom: 8, gap: 16 }}>
      {children}
    </ScrollView>
  );
}

function StoryCard({
  index,
  title,
  emoji,
  caption,
  unfinished,
  onPress,
}: {
  index: number;
  title: string;
  emoji: string;
  caption: string;
  unfinished?: boolean;
  onPress: () => void;
}) {
  const palette = usePalette();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={`${title}. ${caption}`} style={{ width: 140 }}>
      <StickerCard color={unfinished ? palette.surface : tintForIndex(palette, index)}>
        <View style={{ height: 140, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontSize: 44 }}>{emoji}</Text>
          {unfinished && (
            <View
              style={{
                position: 'absolute',
                right: 6,
                top: 6,
                width: 26,
                height: 26,
                borderRadius: 13,
                backgroundColor: palette.action,
                borderWidth: outlineWidthThin,
                borderColor: palette.outline,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Icon name="edit" size={14} color={palette.onAction} />
            </View>
          )}
        </View>
      </StickerCard>
      <CardTitle title={title} caption={caption} />
    </Pressable>
  );
}

function NewStoryCard({ onPress }: { onPress: () => void }) {
  const palette = usePalette();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel="Create a story" style={{ width: 140 }}>
      <StickerCard>
        <View style={{ height: 140, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="add" size={56} color={palette.ink} />
        </View>
      </StickerCard>
      <CardTitle title="Create a story" caption=" " />
    </Pressable>
  );
}

function NoBooks() {
  const palette = usePalette();
  return (
    <StickerCard padding={20}>
      <View style={{ alignItems: 'center' }}>
        <Text style={{ fontSize: 40 }}>📚</Text>
        <Text style={[display(18, palette.ink, 700), { marginTop: 8 }]}>No books yet</Text>
        <Text style={[body(15, palette.inkMuted), { textAlign: 'center', marginTop: 4 }]}>
          Ask a grown-up to add some books for you.
        </Text>
      </View>
    </StickerCard>
  );
}

function Banner({
  emoji,
  title,
  message,
  action,
  onAction,
}: {
  emoji: string;
  title: string;
  message: string;
  action: string;
  onAction: () => void;
}) {
  const palette = usePalette();
  return (
    <View style={{ marginBottom: 16 }}>
      <StickerCard color={palette.tintYellow} padding={16}>
        <View style={{ flexDirection: 'row' }}>
          <Text style={{ fontSize: 36 }}>{emoji}</Text>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={display(18, palette.ink, 700)}>{title}</Text>
            <Text style={[body(15, palette.ink, 500), { marginTop: 2 }]}>{message}</Text>
            <View style={{ height: 12 }} />
            <StoryButton label={action} onPress={onAction} />
          </View>
        </View>
      </StickerCard>
    </View>
  );
}

/** Shown when the child taps Read or Create after today's time is used up. */
function DoneForTodaySheet() {
  const palette = usePalette();
  const nav = useNav();
  return (
    <SheetPanel>
      <View style={{ alignItems: 'center' }}>
        <Text style={{ fontSize: 48 }}>🌙</Text>
        <Text style={[display(22, palette.ink, 700), { marginTop: 8 }]}>All done for today!</Text>
        <Text style={[body(15, palette.ink), { textAlign: 'center', marginTop: 8 }]}>
          You've used today's reading time. Come back tomorrow!
        </Text>
      </View>
      <View style={{ flexDirection: 'row', gap: 12, marginTop: 20 }}>
        <StoryButton label="Grown-up unlock" filled={false} showArrow={false} style={{ flex: 1 }} onPress={() => nav.pop('unlock')} />
        <StoryButton label="OK" showArrow={false} style={{ flex: 1 }} onPress={() => nav.pop()} />
      </View>
    </SheetPanel>
  );
}

const NAV_ITEMS: { icon: IconName; label: string }[] = [
  { icon: 'home', label: 'Home' },
  { icon: 'local-library', label: 'My Library' },
  { icon: 'edit', label: 'Create a Story' },
];

/** Home, My Library and Create as three stickers on a yellow band. */
function NavBar({ current, onPress }: { current: number; onPress: (i: number) => void }) {
  const palette = usePalette();
  const insets = useSafeAreaInsets();
  return (
    <View
      style={{
        backgroundColor: palette.header,
        borderTopWidth: outlineWidth,
        borderTopColor: palette.outline,
        paddingTop: 10,
        paddingBottom: insets.bottom + 12,
        paddingLeft: 12,
        paddingRight: 14,
        flexDirection: 'row',
        gap: 10,
      }}
    >
      {NAV_ITEMS.map((item, i) => {
        const on = i === current;
        const ink = on ? palette.onAction : palette.ink;
        return (
          <View key={item.label} style={{ flex: 1 }}>
            <StickerCard
              color={on ? palette.action : palette.surface}
              radius={radiusButton}
              depth={3}
              accessibilityLabel={item.label}
              onPress={() => onPress(i)}
              padding={{ paddingHorizontal: 4, paddingVertical: 6 }}
            >
              <View style={{ alignItems: 'center' }}>
                <Icon name={item.icon} size={22} color={ink} />
                <Text numberOfLines={1} adjustsFontSizeToFit style={[display(13, ink, 700), { marginTop: 2 }]}>
                  {item.label}
                </Text>
              </View>
            </StickerCard>
          </View>
        );
      })}
    </View>
  );
}
