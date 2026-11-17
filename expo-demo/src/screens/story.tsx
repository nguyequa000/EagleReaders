import * as Speech from 'expo-speech';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  useWindowDimensions,
  View,
  type ScrollViewInstance,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { PaperBackground } from '../components/PaperBackground';
import {
  Icon,
  RowLabel,
  SheetPanel,
  Spinner,
  SproutBubble,
  StickerHeader,
  StickerIconButton,
  StoryButton,
  ThemeSticker,
} from '../components/sticker';
import { useToast } from '../components/Toast';
import { useNav, useRoute } from '../nav/Navigator';
import { ActivityService } from '../services/activity';
import { CoinService } from '../services/coins';
import { FamilySettings } from '../services/familySettings';
import { ReaderAudience, ageBandInfo } from '../services/readerAudience';
import { characterPhrase, LocalSproutIdeas, stageHint, type StoryStage } from '../services/sproutPrompts';
import {
  BAD_WORDS_MESSAGE,
  continuedWith,
  fallbackStory,
  generateStory,
  hasBadWords,
  isQuotaError,
  MAX_CHOICE_LENGTH,
  MAX_IDEA_LENGTH,
  questionToJson,
  SafetyStopError,
  storyEnded,
  type Story,
} from '../services/storyGenerator';
import {
  countWords,
  DEFAULT_TITLE,
  draftIsEmpty,
  freeDraft,
  guidedDraft,
  StoryStore,
  type SavedStory,
  type StoredStory,
  type StoryDraft,
} from '../services/storyStore';
import {
  HeroColorRow,
  HeroFeatureRow,
  HeroOptionStrip,
  HeroPreview,
  Illustration,
  OptionGrid,
  PreviewChip,
  StoryScaffold,
  usePreviewHeight,
} from '../story/components';
import {
  colorsFor,
  effectiveCharacter,
  emptyConfig,
  heroLabel,
  MOODS,
  optionByLabel,
  randomized,
  selectedValue,
  SETTINGS,
  storyConfigToMap,
  storyTitle,
  withOption,
  type HeroConfig,
  type HeroFeature,
  type StoryConfig,
  type StoryOption,
} from '../story/model';
import { usePalette } from '../theme/ThemeProvider';
import {
  body,
  cardShadow,
  darkPalette,
  depth,
  display,
  lightPalette,
  outlineWidth,
  outlineWidthThin,
  radiusButton,
  radiusTile,
  tintForIndex,
} from '../theme/palette';
import { useMounted } from './family';
import { ComprehensionScreen } from './quiz';

type Toast = ReturnType<typeof useToast>;

/**
 * Logs a new story for the parent dashboard and pays the story coins.
 * Fire-and-forget: the coin toast follows once the award lands.
 */
export function recordStoryCreated(toast: Toast, childId: string, title: string) {
  ActivityService.logEvent(childId, 'story_created', { title }).catch(() => {});
  CoinService.awardStory(childId, title)
    .then((coins) => {
      if (coins > 0) toast.coins(coins);
    })
    .catch(() => {});
}

/** Where a story stands, for whoever saves it. */
export type StoryProgress = { story: Story; page: number; chapters: number; finished: boolean };

/**
 * Saves a Beginning writer story as the child reads it, for the dashboard's
 * "My Stories" and "Still Working On". Saves run one after another, so the
 * first one's new id is what later ones update.
 */
export class AiStorySaver {
  private queue: Promise<void> = Promise.resolve();
  private finished = false;

  constructor(
    private childId: string,
    private config: StoryConfig,
    public id: string | null = null,
  ) {}

  save = (progress: StoryProgress) => {
    if (progress.finished) this.finished = true;
    const finished = this.finished;
    this.queue = this.queue.then(() => this.write(progress, finished));
  };

  private async write(progress: StoryProgress, finished: boolean) {
    const story = progress.story;
    const text = story.pages.join('\n\n');
    try {
      this.id = await StoryStore.saveAiStory(
        this.childId,
        {
          title: story.title,
          text,
          pages: story.pages,
          choices: story.choices,
          questions: story.questions.map(questionToJson),
          page: progress.page,
          chapters: progress.chapters,
          hero: effectiveCharacter(this.config.hero),
          heroName: this.config.hero.name ?? null,
          mood: this.config.mood ?? null,
          setting: this.config.setting ?? null,
          config: storyConfigToMap(this.config),
          totalWords: countWords(text),
        },
        this.id,
        finished,
      );
    } catch {
      // A story that can't be saved still reads; it just won't be listed.
    }
  }
}

/**
 * The story flow: build a hero, pick a place and a feeling, name the hero and
 * add an idea, then choose who writes it.
 */
export function StoryFlowScreen({ childId, childName = '' }: { childId?: string; childName?: string }) {
  const nav = useNav();
  const toast = useToast();
  const [step, setStep] = useState(1);
  const [config, setConfig] = useState<StoryConfig>(emptyConfig);
  const starting = useRef(false);
  const writing = useRef(false);

  const go = (next: number, c: StoryConfig = config) => {
    setConfig(c);
    setStep(next);
  };

  /** Beginning writer: Sprout writes the story; the reader takes the flow's place. */
  const startBeginner = (c: StoryConfig) => {
    if (starting.current) return;
    starting.current = true;
    if (childId) recordStoryCreated(toast, childId, storyTitle(c));
    const saver = childId ? new AiStorySaver(childId, c) : null;
    nav.replace(
      <StoryReaderScreen
        config={c}
        childId={childId}
        childName={childName}
        onNextPage={() => openFinished(nav, childId, childName)}
        onProgress={saver?.save}
      />,
    );
  };

  /** Advanced writer: the child writes it, Sprout only asks questions. */
  const startAdvanced = async (c: StoryConfig) => {
    if (starting.current || writing.current) return;
    writing.current = true;
    const saved = await nav.push<SavedStory>(
      <StoryWriterScreen config={c} childId={childId} showIdeas={FamilySettings.ai.sproutIdeas} />,
    );
    writing.current = false;
    if (!saved) return;
    starting.current = true;
    const typed = saved.title.trim();
    if (childId) recordStoryCreated(toast, childId, !typed || typed === DEFAULT_TITLE ? storyTitle(c) : typed);
    nav.replace(
      <MyStoryScreen title={saved.title} text={saved.text} onFinish={() => openFinished(nav, childId, childName)} />,
    );
  };

  switch (step) {
    case 1:
      return <StoryHeroScreen hero={config.hero} onBack={() => nav.pop()} onNext={(hero) => go(2, { ...config, hero })} />;
    case 2:
      return <StorySettingScreen config={config} onBack={() => go(1)} onNext={(c) => go(3, c)} />;
    case 3:
      return (
        <StoryMoodScreen
          config={config}
          options={ageBandInfo[ReaderAudience.current].allowsSpooky ? MOODS : MOODS.filter((m) => m.label !== 'Spooky')}
          onBack={() => go(2)}
          onNext={(c) => go(4, c)}
        />
      );
    case 4:
      return (
        <StorySummaryScreen
          config={config}
          onBack={() => go(3)}
          onEditHero={() => go(1)}
          onIdeaChanged={(idea) => setConfig((c) => ({ ...c, idea }))}
          onStart={(c) => {
            // With AI stories turned off there is nothing to choose.
            if (FamilySettings.ai.aiStories) go(5, c);
            else {
              setConfig(c);
              startAdvanced(c);
            }
          }}
        />
      );
    default:
      return (
        <StoryModeScreen
          onBack={() => go(4)}
          onChoose={(level) => (level === 'beginning' ? startBeginner(config) : startAdvanced(config))}
        />
      );
  }
}

/** The what-next screen, on top of the story; both exits unwind it. */
function openFinished(nav: ReturnType<typeof useNav>, childId?: string, childName = '') {
  nav.push(
    <StoryFinishedScreen
      onCreateAnother={() => {
        nav.pop();
        nav.replace(<StoryFlowScreen childId={childId} childName={childName} />);
      }}
      onReturnHome={() => nav.popMany(2)}
    />,
  );
}

function StoryHeroScreen({
  hero: initial,
  onBack,
  onNext,
}: {
  hero: HeroConfig;
  onBack: () => void;
  onNext: (hero: HeroConfig) => void;
}) {
  const palette = usePalette();
  const [hero, setHero] = useState(initial);
  const [feature, setFeature] = useState<HeroFeature>('hero');
  const height = usePreviewHeight(0.25, 190, 270);
  const stripLabel = feature === 'hero' ? 'PICK YOUR HERO' : feature === 'pose' ? 'WHAT ARE THEY DOING?' : 'PICK A PET';
  return (
    <StoryScaffold step={1} title="Build your hero!" onBack={onBack} footer={<StoryButton label="Next" onPress={() => onNext(hero)} />}>
      <HeroPreview hero={hero} height={height}>
        <View style={{ position: 'absolute', top: 10, right: 10 }}>
          <Pressable onPress={() => setHero(randomized(hero))} accessibilityRole="button" accessibilityLabel="Surprise me">
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                paddingHorizontal: 13,
                paddingVertical: 7,
                backgroundColor: palette.surface,
                borderRadius: radiusButton,
                borderWidth: 1.5,
                borderColor: palette.action,
              }}
            >
              <Icon name="casino" size={16} color={palette.action} />
              <Text style={[display(13, palette.action, 600), { marginLeft: 6 }]}>Surprise me!</Text>
            </View>
          </Pressable>
        </View>
      </HeroPreview>
      <View style={{ height: 18 }} />
      <HeroFeatureRow selected={feature} onSelect={setFeature} />
      <View style={{ height: 18 }} />
      <RowLabel text={stripLabel} />
      <View style={{ height: 8 }} />
      <HeroOptionStrip feature={feature} hero={hero} onSelect={(v) => setHero(withOption(hero, feature, v))} />
      {colorsFor(feature).length > 0 && (
        <>
          <View style={{ height: 16 }} />
          <RowLabel text="OUTFIT COLOUR" />
          <View style={{ height: 8 }} />
          <HeroColorRow
            feature={feature}
            selected={hero.outfitColor}
            onSelect={(hex) => setHero({ ...hero, outfitColor: hex })}
          />
        </>
      )}
      <View style={{ height: 12 }} />
    </StoryScaffold>
  );
}

function StorySettingScreen({
  config,
  onBack,
  onNext,
}: {
  config: StoryConfig;
  onBack: () => void;
  onNext: (c: StoryConfig) => void;
}) {
  const [selected, setSelected] = useState(config.setting ?? null);
  const height = usePreviewHeight(0.21, 150, 230);
  return (
    <StoryScaffold
      step={2}
      title="Pick a place!"
      onBack={onBack}
      footer={<StoryButton label="Next" onPress={selected ? () => onNext({ ...config, setting: selected }) : null} />}
    >
      <HeroPreview hero={config.hero} height={height} setting={selected} mood={config.mood} />
      <View style={{ height: 12 }} />
      <RowLabel text="CHOOSE A PLACE" />
      <View style={{ height: 10 }} />
      <OptionGrid options={SETTINGS} selected={selected} onSelect={setSelected} />
    </StoryScaffold>
  );
}

function StoryMoodScreen({
  config,
  options,
  onBack,
  onNext,
}: {
  config: StoryConfig;
  options: StoryOption[];
  onBack: () => void;
  onNext: (c: StoryConfig) => void;
}) {
  // A feeling no longer on offer is dropped rather than kept selected.
  const [selected, setSelected] = useState(options.some((o) => o.label === config.mood) ? config.mood ?? null : null);
  const height = usePreviewHeight(0.21, 150, 230);
  return (
    <StoryScaffold
      step={3}
      title="Pick a feeling!"
      onBack={onBack}
      footer={<StoryButton label="Next" onPress={selected ? () => onNext({ ...config, mood: selected }) : null} />}
    >
      <HeroPreview hero={config.hero} height={height} setting={config.setting} mood={selected} />
      <View style={{ height: 12 }} />
      <RowLabel text="CHOOSE A MOOD" />
      <View style={{ height: 10 }} />
      <OptionGrid options={options} selected={selected} onSelect={setSelected} />
    </StoryScaffold>
  );
}

function StorySummaryScreen({
  config,
  onBack,
  onEditHero,
  onIdeaChanged,
  onStart,
}: {
  config: StoryConfig;
  onBack: () => void;
  onEditHero: () => void;
  onIdeaChanged: (idea: string) => void;
  onStart: (c: StoryConfig) => void;
}) {
  const palette = usePalette();
  const nav = useNav();
  const [name, setName] = useState(config.hero.name ?? '');
  const [idea, setIdea] = useState(config.idea);
  const height = usePreviewHeight(0.32, 200, 310);
  const current: StoryConfig = { ...config, hero: { ...config.hero, name: name.trim() || null }, idea };
  // Both go to the story writer, so neither may carry unkind words.
  const blocked = hasBadWords(name) || hasBadWords(idea);

  const editIdea = async () => {
    const next = await nav.showSheet<string>(<IdeaSheet initial={idea} />);
    if (next == null) return;
    setIdea(next);
    onIdeaChanged(next);
  };

  const row = (caption: string, option: StoryOption | null, tint: string) => (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        paddingHorizontal: 14,
        paddingVertical: 10,
        backgroundColor: tint,
        borderRadius: radiusTile,
        borderWidth: outlineWidthThin,
        borderColor: palette.outline,
        marginBottom: 10,
        ...cardShadow(palette, { depth: 3 }),
      }}
    >
      <View style={{ width: 34, height: 34 }}>{option ? <Illustration asset={option.asset} size={34} /> : null}</View>
      <Text style={[body(14, palette.inkMuted, 600), { flex: 1, marginLeft: 12 }]}>{caption}</Text>
      <Text style={display(15, palette.ink, 600)}>{option?.label ?? '—'}</Text>
    </View>
  );

  return (
    <StoryScaffold
      step={4}
      title="Your story!"
      onBack={onBack}
      footer={<StoryButton label="Start Reading!" showArrow={false} onPress={blocked ? null : () => onStart(current)} />}
    >
      <HeroPreview hero={current.hero} height={height} setting={config.setting} mood={config.mood}>
        <View style={{ position: 'absolute', top: 10, left: 10 }}>
          <PreviewChip label="Edit hero" icon="tune" onPress={onEditHero} />
        </View>
        <View style={{ position: 'absolute', top: 10, right: 10 }}>
          <PreviewChip label={idea ? 'Edit idea' : 'Add an idea'} icon="lightbulb-outline" onPress={editIdea} />
        </View>
      </HeroPreview>
      <View style={{ height: 16 }} />
      <RowLabel text="NAME YOUR HERO" />
      <View style={{ height: 8 }} />
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          backgroundColor: palette.surface,
          borderRadius: radiusTile,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          paddingHorizontal: 14,
          ...cardShadow(palette, { depth: 3 }),
        }}
      >
        <Icon name="edit" size={18} color={palette.action} />
        <TextInput
          value={name}
          onChangeText={setName}
          maxLength={20}
          autoCapitalize="words"
          placeholder="Give them a name"
          placeholderTextColor={palette.inkMuted}
          keyboardAppearance={palette.isDark ? 'dark' : 'light'}
          style={[display(16, palette.ink, 600), { flex: 1, paddingVertical: 14, marginLeft: 10 }]}
        />
      </View>
      {blocked && <Text style={[body(14, palette.ink), { marginTop: 6 }]}>{BAD_WORDS_MESSAGE}</Text>}
      <View style={{ height: 16 }} />
      <RowLabel text="YOUR STORY" />
      <View style={{ height: 8 }} />
      {row('Place', optionByLabel(SETTINGS, config.setting), tintForIndex(palette, 1))}
      {row('Feeling', optionByLabel(MOODS, config.mood), tintForIndex(palette, 0))}
    </StoryScaffold>
  );
}

/** Where the child types what they want their story to be about. */
function IdeaSheet({ initial }: { initial: string }) {
  const palette = usePalette();
  const nav = useNav();
  const [text, setText] = useState(initial);
  const unkind = hasBadWords(text);
  return (
    <SheetPanel>
      <RowLabel text="YOUR STORY IDEA" />
      <View style={{ height: 8 }} />
      <TextInput
        value={text}
        onChangeText={setText}
        autoFocus
        multiline
        maxLength={MAX_IDEA_LENGTH}
        placeholder="A fox finds a map to a hidden treehouse..."
        placeholderTextColor={palette.inkMuted}
        keyboardAppearance={palette.isDark ? 'dark' : 'light'}
        style={[
          body(16, palette.ink, 400, 1.4),
          {
            minHeight: 90,
            maxHeight: 160,
            padding: 12,
            backgroundColor: palette.surface,
            borderWidth: outlineWidth,
            borderColor: unkind ? palette.tintCoral : palette.outline,
            borderRadius: radiusButton,
            textAlignVertical: 'top',
          },
        ]}
      />
      {unkind && <Text style={[body(13, palette.ink, 700), { marginTop: 4 }]}>{BAD_WORDS_MESSAGE}</Text>}
      <View style={{ height: 12 }} />
      <StoryButton label="Use this idea" showArrow={false} onPress={unkind ? null : () => nav.pop(text.trim())} />
    </SheetPanel>
  );
}

type WriterLevel = 'beginning' | 'advanced';

function StoryModeScreen({ onBack, onChoose }: { onBack: () => void; onChoose: (level: WriterLevel) => void }) {
  const palette = usePalette();
  const card = (level: WriterLevel, title: string, caption: string, icon: 'auto-stories' | 'edit', tint: string) => (
    <LevelCard title={title} caption={caption} icon={icon} tint={tint} onPress={() => onChoose(level)} />
  );
  return (
    <StoryScaffold
      step={4}
      title="How do you want to write?"
      prompt="Do you want me to help, or do you want to write it yourself?"
      onBack={onBack}
    >
      {card('beginning', 'Beginning writer', 'Sprout writes the story with you.', 'auto-stories', tintForIndex(palette, 1))}
      <View style={{ height: 16 }} />
      {card('advanced', 'Advanced writer', 'You write the story. Sprout gives ideas.', 'edit', tintForIndex(palette, 0))}
    </StoryScaffold>
  );
}

function LevelCard({
  title,
  caption,
  icon,
  tint,
  onPress,
}: {
  title: string;
  caption: string;
  icon: 'auto-stories' | 'edit';
  tint: string;
  onPress: () => void;
}) {
  const palette = usePalette();
  const [held, setHeld] = useState(false);
  return (
    <Pressable
      onPress={onPress}
      onPressIn={() => setHeld(true)}
      onPressOut={() => setHeld(false)}
      accessibilityRole="button"
      accessibilityLabel={`${title}. ${caption}`}
    >
      <View
        style={{
          transform: [{ translateX: held ? depth : 0 }, { translateY: held ? depth : 0 }],
          minHeight: 96,
          padding: 16,
          flexDirection: 'row',
          alignItems: 'center',
          backgroundColor: tint,
          borderRadius: radiusTile,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          ...cardShadow(palette, { pressed: held }),
        }}
      >
        <View
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            backgroundColor: palette.surface,
            borderWidth: outlineWidthThin,
            borderColor: palette.outline,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={icon} size={28} color={palette.ink} />
        </View>
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text style={display(20, palette.ink, 700)}>{title}</Text>
          <Text style={[body(15, palette.ink), { marginTop: 4 }]}>{caption}</Text>
        </View>
      </View>
    </Pressable>
  );
}

const MAX_CHAPTERS = 5;
const TIMEOUT_MS = 60000;
const HIGHLIGHT = darkPalette.headerInk;

function withTimeout<T>(p: Promise<T>): Promise<T> {
  return Promise.race([p, new Promise<T>((_, reject) => setTimeout(() => reject(new Error('Timed out')), TIMEOUT_MS))]);
}

/**
 * Reads the story Sprout writes from the child's choices, a chapter at a
 * time: the child picks (or types) what happens next, can have each page read
 * aloud, and answers a short quiz once the story ends.
 */
export function StoryReaderScreen({
  config,
  childId,
  childName = '',
  onNextPage,
  initialStory,
  initialPage = 0,
  initialChapters = 1,
  onProgress,
}: {
  config: StoryConfig;
  childId?: string;
  childName?: string;
  onNextPage?: () => void;
  initialStory?: Story;
  initialPage?: number;
  initialChapters?: number;
  onProgress?: (p: StoryProgress) => void;
}) {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const route = useRoute();
  const mounted = useMounted();
  const insets = useSafeAreaInsets();
  const { width: screenWidth } = useWindowDimensions();
  const resumed = initialStory && initialStory.pages.length > 0 ? initialStory : null;
  const startPage = resumed ? Math.max(0, Math.min(initialPage, resumed.pages.length - 1)) : 0;

  const [story, setStory] = useState<Story | null>(resumed);
  const [offline, setOffline] = useState(false);
  const [resting, setResting] = useState(false);
  const [safetyStop, setSafetyStop] = useState(false);
  const [chapters, setChapters] = useState(resumed ? initialChapters : 1);
  const [writing, setWriting] = useState(false);
  const [page, setPage] = useState(startPage);
  const [speaking, setSpeaking] = useState(false);
  const [word, setWord] = useState<{ start: number; end: number } | null>(null);
  const [typingOwn, setTypingOwn] = useState(false);
  const [ownIdea, setOwnIdea] = useState('');
  const [pageWidth, setPageWidth] = useState(screenWidth - 40);
  const list = useRef<FlatList<string>>(null);
  const finishing = useRef(false);
  const reachedEnd = useRef(false);
  const state = useRef({ story, page, chapters, offline, safetyStop });
  state.current = { story, page, chapters, offline, safetyStop };

  /** Hands the story to onProgress; not for the offline classic. */
  const report = useCallback(
    (finished = false) => {
      const s = state.current;
      if (!s.story || s.offline || s.safetyStop) return;
      if (finished) reachedEnd.current = true;
      onProgress?.({ story: s.story, page: s.page, chapters: s.chapters, finished: reachedEnd.current });
    },
    [onProgress],
  );

  const load = useCallback(async () => {
    setStory(null);
    setPage(0);
    setChapters(1);
    let next: Story;
    let isOffline = false;
    let isResting = false;
    try {
      next = await withTimeout(generateStory(config));
    } catch (e) {
      if (e instanceof SafetyStopError) {
        if (mounted.current) setSafetyStop(true);
        return;
      }
      next = fallbackStory(config);
      isOffline = true;
      isResting = isQuotaError(e);
    }
    if (!mounted.current) return;
    setStory(next);
    setOffline(isOffline);
    setResting(isResting);
    state.current = { ...state.current, story: next, page: 0, chapters: 1, offline: isOffline };
    report();
  }, [config, mounted, report]);

  useEffect(() => {
    if (!resumed) load();
    return () => {
      // Remember the page they stopped on.
      report();
      Speech.stop();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (resumed && startPage > 0) {
      setTimeout(() => list.current?.scrollToIndex({ index: startPage, animated: false }), 50);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const stopSpeech = () => {
    Speech.stop();
    setSpeaking(false);
    setWord(null);
  };

  const goTo = (index: number, animated = true) => {
    list.current?.scrollToIndex({ index, animated });
  };

  /** Writes the next chapter from the child's choice, or the ending when null. */
  const continueStory = async (choice: string | null) => {
    if (!story || writing) return;
    stopSpeech();
    setWriting(true);
    try {
      const chapter = await withTimeout(generateStory(config, story, choice));
      if (!mounted.current) return;
      const next = continuedWith(story, chapter);
      setStory(next);
      setChapters((c) => c + 1);
      setOwnIdea('');
      setTypingOwn(false);
      state.current = { ...state.current, story: next, chapters: state.current.chapters + 1 };
      report();
      const target = story.pages.length;
      setTimeout(() => goTo(target), 150);
    } catch (e) {
      if (e instanceof SafetyStopError) {
        if (mounted.current) setSafetyStop(true);
      } else {
        toast.show(isQuotaError(e) ? 'Sprout needs a short rest. Try again in a minute!' : "Sprout couldn't write that part. Try again!");
      }
    } finally {
      if (mounted.current) setWriting(false);
    }
  };

  const continueWithOwnIdea = () => {
    if (hasBadWords(ownIdea)) return;
    if (ownIdea.trim()) continueStory(ownIdea.trim());
  };

  const toggleSpeech = () => {
    if (speaking) return stopSpeech();
    if (!story) return;
    setSpeaking(true);
    Speech.speak(story.pages[page], {
      language: 'en-US',
      rate: 0.9,
      onBoundary: (e: { charIndex: number; charLength: number }) => {
        if (mounted.current) setWord({ start: e.charIndex, end: e.charIndex + e.charLength });
      },
      onDone: () => {
        if (mounted.current) stopSpeechState();
      },
      onStopped: () => {
        if (mounted.current) stopSpeechState();
      },
      onError: () => {
        if (mounted.current) stopSpeechState();
      },
    });
  };
  const stopSpeechState = () => {
    setSpeaking(false);
    setWord(null);
  };

  /** The quiz (when the story ended with one), then whatever comes next. */
  const finish = async () => {
    if (finishing.current || !story) return;
    finishing.current = true;
    stopSpeech();
    report(true);
    if (story.questions.length > 0 && childId && FamilySettings.ai.aiQuizzes) {
      await nav.push(
        <ComprehensionScreen
          childId={childId}
          childName={childName}
          bookTitle={story.title}
          chapterNumber={chapters}
          questions={story.questions}
        />,
      );
      if (!mounted.current) return;
    }
    finishing.current = false;
    if (onNextPage) onNextPage();
    else nav.pop(true);
  };

  const pageText = (text: string, current: boolean) => {
    const style = body(22, palette.ink, 400, 1.6);
    if (!current || !word || word.end > text.length || word.start >= word.end) return <Text style={style}>{text}</Text>;
    return (
      <Text style={style}>
        {text.slice(0, word.start)}
        <Text style={{ backgroundColor: HIGHLIGHT, color: lightPalette.ink }}>{text.slice(word.start, word.end)}</Text>
        {text.slice(word.end)}
      </Text>
    );
  };

  const choices = () => {
    if (!story) return null;
    if (writing) {
      return (
        <View style={{ paddingTop: 32, alignItems: 'center' }}>
          <Spinner />
          <Text style={[display(16, palette.ink), { marginTop: 12 }]}>Sprout is writing what happens next…</Text>
        </View>
      );
    }
    const more = chapters < MAX_CHAPTERS;
    const unkind = hasBadWords(ownIdea);
    return (
      <View style={{ paddingTop: 32 }}>
        <Text style={[display(20, palette.ink), { textAlign: 'center', marginBottom: 12 }]}>What happens next?</Text>
        {more &&
          story.choices.map((c) => (
            <View key={c} style={{ marginBottom: 10 }}>
              <StoryButton label={c} showArrow={false} onPress={() => continueStory(c)} />
            </View>
          ))}
        {more && !typingOwn && (
          <View style={{ marginBottom: 10 }}>
            <StoryButton label="I want to write what happens!" filled={false} showArrow={false} onPress={() => setTypingOwn(true)} />
          </View>
        )}
        {more && typingOwn && (
          <View style={{ marginBottom: 8 }}>
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                backgroundColor: palette.surface,
                borderRadius: 12,
                borderWidth: outlineWidthThin,
                borderColor: unkind ? palette.tintCoral : palette.outline,
                paddingLeft: 12,
              }}
            >
              <TextInput
                value={ownIdea}
                onChangeText={setOwnIdea}
                autoFocus
                maxLength={MAX_CHOICE_LENGTH}
                returnKeyType="send"
                onSubmitEditing={continueWithOwnIdea}
                placeholder="What happens next?"
                placeholderTextColor={palette.inkMuted}
                keyboardAppearance={palette.isDark ? 'dark' : 'light'}
                style={[body(16, palette.ink, 400, 1.35), { flex: 1, paddingVertical: 12 }]}
              />
              <Pressable onPress={continueWithOwnIdea} accessibilityLabel="Use my idea" style={{ padding: 12 }}>
                <Icon name="send" color={palette.ink} />
              </Pressable>
            </View>
            {unkind && <Text style={[body(13, palette.ink, 700), { marginTop: 4 }]}>{BAD_WORDS_MESSAGE}</Text>}
          </View>
        )}
        <StoryButton label="Finish the story" filled={false} showArrow={false} small onPress={() => continueStory(null)} />
      </View>
    );
  };

  const isLast = !!story && page === story.pages.length - 1;
  const readAloud = !!story && FamilySettings.ai.readAloud;

  return (
    <PaperBackground>
      <StickerHeader
        title="Your Story"
        showBack={!onNextPage && route.canPop}
        onBack={() => nav.pop()}
        centerTitle={false}
        trailing={
          <>
            {readAloud && (
              <StickerIconButton
                icon={speaking ? 'stop' : 'volume-up'}
                label={speaking ? 'Stop reading' : 'Read aloud'}
                onPress={toggleSpeech}
              />
            )}
            {onNextPage && (
              <StickerIconButton
                icon="arrow-forward"
                label="I'm done reading"
                onPress={() => {
                  stopSpeech();
                  onNextPage();
                }}
              />
            )}
          </>
        }
      />
      {safetyStop ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
          <Icon name="favorite" size={48} color={palette.action} />
          <Text style={[display(22, palette.ink), { textAlign: 'center', marginTop: 16 }]}>
            Let's talk to a grown-up about that
          </Text>
          <Text style={[body(15, palette.ink), { textAlign: 'center', marginTop: 8 }]}>
            Some feelings are big. A grown-up you trust can help.
          </Text>
          <View style={{ height: 16, alignSelf: 'stretch' }} />
          <StoryButton label="Go back" showArrow={false} onPress={() => nav.pop()} style={{ alignSelf: 'stretch' }} />
        </View>
      ) : !story ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <Spinner />
          <Text style={[display(18, palette.ink), { marginTop: 16 }]}>Sprout is writing your story…</Text>
        </View>
      ) : (
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <View style={{ flex: 1, paddingHorizontal: 20, paddingTop: 16 }}>
            <View
              style={{
                padding: 16,
                backgroundColor: palette.surface,
                borderRadius: radiusTile,
                borderWidth: 1,
                borderColor: palette.line,
                ...cardShadow(palette),
              }}
            >
              <Text style={display(12, palette.inkMuted, 600, 1.4)}>STORY PREVIEW</Text>
              {[
                ['Hero', config.hero.name || 'Your hero'],
                ['Mood', config.mood],
                ['Setting', config.setting],
              ].map(([caption, value]) => (
                <Text key={caption ?? ''} style={[body(14, palette.inkMuted), { marginTop: 4 }]}>
                  {caption}: <Text style={display(14, palette.ink, 600)}>{value ?? 'unknown'}</Text>
                </Text>
              ))}
            </View>
            <View style={{ height: 12 }} />
            {offline && (
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  padding: 12,
                  marginBottom: 12,
                  backgroundColor: palette.surface,
                  borderRadius: radiusTile,
                  borderWidth: 1,
                  borderColor: palette.line,
                }}
              >
                <Text style={[body(14, palette.ink), { flex: 1 }]}>
                  {resting
                    ? "Sprout is resting after lots of stories, so here's a classic! Try again in a minute."
                    : "Sprout couldn't reach the story cloud, so here's a classic!"}
                </Text>
                <Pressable onPress={load} style={{ padding: 8 }}>
                  <Text style={display(15, palette.ink, 700)}>Try again</Text>
                </Pressable>
              </View>
            )}
            <Text style={[display(22, palette.ink), { textAlign: 'center', marginBottom: 8 }]}>{story.title}</Text>
            <View style={{ flex: 1 }} onLayout={(e) => setPageWidth(e.nativeEvent.layout.width)}>
              <FlatList
                ref={list}
                data={story.pages}
                horizontal
                pagingEnabled
                showsHorizontalScrollIndicator={false}
                keyExtractor={(_, i) => String(i)}
                getItemLayout={(_, index) => ({ length: pageWidth, offset: pageWidth * index, index })}
                onMomentumScrollEnd={(e) => {
                  const next = Math.round(e.nativeEvent.contentOffset.x / pageWidth);
                  if (next !== page) {
                    stopSpeech();
                    setPage(next);
                  }
                }}
                onScrollToIndexFailed={() => {}}
                renderItem={({ item, index }) => (
                  <ScrollView style={{ width: pageWidth }} keyboardShouldPersistTaps="handled">
                    {pageText(item, index === page)}
                    {index === story.pages.length - 1 && !storyEnded(story) && choices()}
                    <View style={{ height: 16 }} />
                  </ScrollView>
                )}
              />
            </View>
            <View style={{ flexDirection: 'row', alignItems: 'center', paddingTop: 12, paddingBottom: insets.bottom + 12 }}>
              <Pressable
                accessibilityLabel="Previous page"
                disabled={page === 0}
                onPress={() => {
                  stopSpeech();
                  setPage(page - 1);
                  goTo(page - 1);
                }}
                style={{ padding: 12, opacity: page === 0 ? 0.3 : 1 }}
              >
                <Icon name="arrow-back-ios" color={palette.ink} />
              </Pressable>
              <Text style={[display(14, palette.inkMuted), { flex: 1, textAlign: 'center' }]}>
                Page {page + 1} of {story.pages.length}
              </Text>
              {isLast && !storyEnded(story) ? (
                <View style={{ width: 48 }} />
              ) : isLast ? (
                <StoryButton
                  label={story.questions.length === 0 || !FamilySettings.ai.aiQuizzes ? 'The End' : 'Quiz time!'}
                  onPress={finish}
                  small
                />
              ) : (
                <Pressable
                  accessibilityLabel="Next page"
                  onPress={() => {
                    stopSpeech();
                    setPage(page + 1);
                    goTo(page + 1);
                  }}
                  style={{ padding: 12 }}
                >
                  <Icon name="arrow-forward-ios" color={palette.ink} />
                </Pressable>
              )}
            </View>
          </View>
        </KeyboardAvoidingView>
      )}
    </PaperBackground>
  );
}

/** A yellow app bar like the Flutter story screens'. */
function StoryBar({ title, onBack }: { title: string; onBack?: () => void }) {
  const route = useRoute();
  const nav = useNav();
  return <StickerHeader title={title} showBack={route.canPop} onBack={onBack ?? (() => nav.pop())} centerTitle={false} trailing={<ThemeSticker />} />;
}

/** The story an Advanced writer wrote, shown back to them as a finished page. */
export function MyStoryScreen({ title, text, onFinish }: { title: string; text: string; onFinish?: () => void }) {
  const palette = usePalette();
  const nav = useNav();
  const insets = useSafeAreaInsets();
  return (
    <PaperBackground>
      <StoryBar title="My Story" />
      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 12 }}>
        <View
          style={{
            padding: 18,
            backgroundColor: palette.surface,
            borderRadius: radiusTile,
            borderWidth: outlineWidth,
            borderColor: palette.outline,
            ...cardShadow(palette, { depth: 3 }),
          }}
        >
          <Text style={display(24, palette.ink, 700)}>{title}</Text>
          <Text style={[body(19, palette.ink, 400, 1.5), { marginTop: 14 }]}>{text}</Text>
        </View>
      </ScrollView>
      <View style={{ paddingHorizontal: 20, paddingTop: 8, paddingBottom: insets.bottom + 20 }}>
        <StoryButton label="The End" onPress={onFinish ?? (() => nav.pop())} />
      </View>
    </PaperBackground>
  );
}

/** Shown after the child turns the last page of their story. */
function StoryFinishedScreen({ onCreateAnother, onReturnHome }: { onCreateAnother: () => void; onReturnHome: () => void }) {
  const insets = useSafeAreaInsets();
  return (
    <PaperBackground>
      <StoryBar title="The End!" />
      <View style={{ flex: 1, padding: 20, paddingBottom: insets.bottom + 24 }}>
        <SproutBubble message="You finished your story! What would you like to do now?" />
        <View style={{ flex: 1 }} />
        <StoryButton label="Create Another Story" showArrow={false} onPress={onCreateAnother} />
        <View style={{ height: 12 }} />
        <StoryButton label="Return Home" showArrow={false} filled={false} onPress={onReturnHome} />
      </View>
    </PaperBackground>
  );
}

const PARTS: StoryStage[] = ['beginning', 'middle', 'end'];
const PART_NAMES: Record<string, string> = { beginning: 'Beginning', middle: 'Middle', end: 'End' };

/**
 * Advanced writer mode: the child writes the story, Sprout only asks
 * questions. Pops with a SavedStory when they finish, or nothing when they go
 * back (after quietly saving a draft).
 */
export function StoryWriterScreen({
  config,
  childId,
  showIdeas = true,
  resume,
}: {
  config: StoryConfig;
  childId?: string;
  showIdeas?: boolean;
  resume?: StoredStory;
}) {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const ideas = useRef(new LocalSproutIdeas()).current;
  const [title, setTitle] = useState(resume && resume.title !== DEFAULT_TITLE ? resume.title : '');
  const [free, setFree] = useState(resume && resume.mode !== 'guided' ? resume.text : '');
  const [guided, setGuided] = useState<Record<string, string>>({
    beginning: resume?.mode === 'guided' ? resume.beginning : '',
    middle: resume?.mode === 'guided' ? resume.middle : '',
    end: resume?.mode === 'guided' ? resume.end : '',
  });
  const [mode, setMode] = useState<'free' | 'guided'>(resume?.mode === 'guided' ? 'guided' : 'free');
  const [sprout, setSprout] = useState<Partial<Record<StoryStage, string>>>({});
  const [ideasShown, setIdeasShown] = useState(resume?.ideasShown ?? 0);
  const [saving, setSaving] = useState(false);
  const draftId = useRef<string | null>(resume?.id ?? null);
  const leaving = useRef(false);
  const scroll = useRef<ScrollViewInstance>(null);

  const name = config.hero.name?.trim();
  const draftFor = (m: 'free' | 'guided'): StoryDraft => {
    const base = {
      title,
      hero: effectiveCharacter(config.hero),
      heroName: name || null,
      mood: config.mood ?? null,
      setting: config.setting ?? null,
      ideasShown,
      config: storyConfigToMap(config),
    };
    return m === 'free'
      ? freeDraft({ ...base, text: free })
      : guidedDraft({ ...base, beginning: guided.beginning, middle: guided.middle, end: guided.end });
  };
  const draft = draftFor(mode);
  const partsWritten = PARTS.filter((p) => guided[p].trim()).length;
  const unkind = [title, ...(mode === 'free' ? [free] : PARTS.map((p) => guided[p]))].some(hasBadWords);
  const canFinish = !!draft.text && !unkind && !saving;

  const askSprout = (stage: StoryStage) => {
    const idea = ideas.nextIdea({
      character: effectiveCharacter(config.hero),
      setting: config.setting,
      mood: config.mood,
      stage,
    });
    setSprout((s) => ({ ...s, [stage]: idea }));
    setIdeasShown((n) => n + 1);
    if (stage === 'any') setTimeout(() => scroll.current?.scrollToEnd({ animated: true }), 100);
  };

  const finish = async () => {
    if (!childId) {
      nav.pop({ id: '', title: draft.title.trim() || DEFAULT_TITLE, text: draft.text } as SavedStory);
      return;
    }
    setSaving(true);
    try {
      const saved = await StoryStore.complete(childId, draft, draftId.current);
      nav.pop(saved);
    } catch {
      setSaving(false);
      toast.show("We couldn't save your story. Try again!");
    }
  };

  /** Back: keep what they wrote as a draft, without a dialog in the way. */
  const leave = async () => {
    if (leaving.current || saving) return;
    leaving.current = true;
    const other = mode === 'free' ? 'guided' : 'free';
    const toSave = draftIsEmpty(draft) ? draftFor(other) : draft;
    if (childId && !draftIsEmpty(toSave)) {
      try {
        draftId.current = await StoryStore.saveDraft(childId, toSave, draftId.current);
      } catch {
        // The child still gets out.
      }
    }
    nav.pop();
  };

  const picks = [name || heroLabel(config.hero), config.setting, config.mood].filter((p): p is string => !!p);

  const field = (
    value: string,
    onChange: (t: string) => void,
    hint: string,
    opts: { maxLength: number; minLines?: number; fontSize?: number; bold?: boolean },
  ) => {
    const multiline = (opts.minLines ?? 1) > 1;
    const size = opts.fontSize ?? 18;
    return (
      <View
        style={{
          backgroundColor: palette.surface,
          borderRadius: radiusTile,
          borderWidth: outlineWidth,
          borderColor: palette.outline,
          paddingHorizontal: 14,
          ...cardShadow(palette, { depth: 3 }),
        }}
      >
        <TextInput
          value={value}
          onChangeText={onChange}
          maxLength={opts.maxLength}
          multiline={multiline}
          autoCapitalize={multiline ? 'sentences' : 'words'}
          placeholder={hint}
          placeholderTextColor={palette.inkMuted}
          keyboardAppearance={palette.isDark ? 'dark' : 'light'}
          style={[
            body(size, palette.ink, opts.bold ? 700 : 400, 1.4),
            { paddingVertical: 14, minHeight: multiline ? (opts.minLines ?? 1) * size * 1.4 + 28 : undefined, textAlignVertical: 'top' },
          ]}
        />
      </View>
    );
  };

  const done = <StoryButton label={saving ? 'Saving…' : "I'm done!"} showArrow={false} onPress={canFinish ? finish : null} />;
  const footer =
    mode === 'guided' ? (
      <View>
        <Text style={[body(15, palette.ink, 600), { textAlign: 'center', marginBottom: 8 }]}>{partsWritten} of 3 parts written</Text>
        {done}
      </View>
    ) : !showIdeas ? (
      done
    ) : (
      <View style={{ flexDirection: 'row', gap: 10 }}>
        <StoryButton label="Need an idea?" filled={false} showArrow={false} style={{ flex: 1 }} onPress={() => askSprout('any')} />
        <View style={{ flex: 1 }}>{done}</View>
      </View>
    );

  return (
    <StoryScaffold step={4} title="My Story" onBack={leave} footer={footer} scrollRef={scroll}>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', gap: 8 }}>
        {picks.map((p, i) => (
          <View
            key={p}
            style={{
              paddingHorizontal: 12,
              paddingVertical: 6,
              backgroundColor: tintForIndex(palette, i + 1),
              borderRadius: radiusButton,
              borderWidth: outlineWidthThin,
              borderColor: palette.outline,
            }}
          >
            <Text style={display(14, palette.ink, 600)}>{p}</Text>
          </View>
        ))}
      </View>
      <View style={{ height: 14 }} />
      <View style={{ flexDirection: 'row', gap: 10 }}>
        <StoryButton label="Free write" showArrow={false} filled={mode === 'free'} small style={{ flex: 1 }} onPress={() => setMode('free')} />
        <StoryButton
          label="Beginning · Middle · End"
          showArrow={false}
          filled={mode === 'guided'}
          small
          style={{ flex: 1 }}
          onPress={() => setMode('guided')}
        />
      </View>
      <View style={{ height: 14 }} />
      {field(title, setTitle, 'Name your story', { maxLength: 60, fontSize: 20, bold: true })}
      <View style={{ height: 14 }} />
      {mode === 'free' ? (
        <>
          {field(free, setFree, 'Once upon a time…', { maxLength: 2000, minLines: 8 })}
          <Text style={[body(14, palette.inkMuted), { textAlign: 'right', marginTop: 6 }]}>{countWords(free)} words</Text>
          {sprout.any && (
            <View style={{ marginTop: 10 }}>
              <SproutBubble message={`Sprout wonders… ${sprout.any}`} />
              <View style={{ flexDirection: 'row', gap: 10, marginTop: 10 }}>
                <StoryButton label="Another idea" filled={false} showArrow={false} small style={{ flex: 1 }} onPress={() => askSprout('any')} />
                <StoryButton
                  label="Got it"
                  filled={false}
                  showArrow={false}
                  small
                  style={{ flex: 1 }}
                  onPress={() => setSprout((s) => ({ ...s, any: undefined }))}
                />
              </View>
            </View>
          )}
        </>
      ) : (
        PARTS.map((part, i) => {
          const written = !!guided[part].trim();
          return (
            <View
              key={part}
              style={{
                marginTop: i > 0 ? 14 : 0,
                padding: 14,
                backgroundColor: tintForIndex(palette, i),
                borderRadius: radiusTile,
                borderWidth: outlineWidthThin,
                borderColor: palette.outline,
                ...cardShadow(palette, { depth: 3 }),
              }}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <View
                  accessible
                  accessibilityLabel={written ? `${PART_NAMES[part]} written` : `Part ${i + 1}`}
                  style={{
                    width: 34,
                    height: 34,
                    borderRadius: 17,
                    backgroundColor: written ? palette.action : palette.surface,
                    borderWidth: outlineWidthThin,
                    borderColor: palette.outline,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  {written ? <Icon name="check" size={20} color={palette.onAction} /> : <Text style={display(16, palette.ink, 700)}>{i + 1}</Text>}
                </View>
                <Text style={[display(19, palette.ink, 700), { flex: 1, marginLeft: 10 }]}>{PART_NAMES[part]}</Text>
                {showIdeas && (
                  <Pressable onPress={() => askSprout(part)} accessibilityRole="button" accessibilityLabel="Ask Sprout">
                    <View
                      style={{
                        flexDirection: 'row',
                        alignItems: 'center',
                        paddingHorizontal: 12,
                        paddingVertical: 8,
                        backgroundColor: palette.action,
                        borderRadius: radiusButton,
                        borderWidth: outlineWidthThin,
                        borderColor: palette.outline,
                        ...cardShadow(palette, { depth: 3 }),
                      }}
                    >
                      <Icon name="lightbulb-outline" size={16} color={palette.onAction} />
                      <Text style={[display(14, palette.onAction, 700), { marginLeft: 6 }]}>Ask Sprout</Text>
                    </View>
                  </Pressable>
                )}
              </View>
              <Text style={[body(15, palette.ink), { marginTop: 6 }]}>
                {stageHint(part, characterPhrase(effectiveCharacter(config.hero)))}
              </Text>
              {sprout[part] && (
                <View style={{ marginTop: 10 }}>
                  <SproutBubble message={sprout[part]!} />
                </View>
              )}
              <View style={{ height: 10 }} />
              {field(guided[part], (t) => setGuided((g) => ({ ...g, [part]: t })), `Write the ${PART_NAMES[part].toLowerCase()} here…`, {
                maxLength: 600,
                minLines: 3,
              })}
            </View>
          );
        })
      )}
      {unkind && <Text style={[body(15, palette.ink), { marginTop: 10 }]}>{BAD_WORDS_MESSAGE}</Text>}
    </StoryScaffold>
  );
}
