import AsyncStorage from '@react-native-async-storage/async-storage';
import { File } from 'expo-file-system';
import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Image, Pressable, ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { WebView as NativeWebView, type WebViewMessageEvent } from 'react-native-webview';

import {
  Icon,
  OptionRow,
  SheetPanel,
  Spinner,
  StickerHeader,
  StickerIconButton,
  StoryButton,
} from '../components/sticker';
import { useToast } from '../components/Toast';
import { useNav } from '../nav/Navigator';
import { ActivityService } from '../services/activity';
import { BookLibrary, positionKey, quizKey, type Book } from '../services/bookLibrary';
import { ChapterQuizTrigger, type FinishedChapter } from '../services/chapterQuiz';
import {
  base64Of,
  chapterHtml,
  mimeOf,
  openEpub,
  pictureChapterAt,
  readPictureBook,
  textOf,
  tocIndexAt,
  type EpubBook,
  type PictureBook,
} from '../services/epub';
import { FamilySettings } from '../services/familySettings';
import {
  generateBookQuestions,
  generateChapterQuestions,
  generatePictureChapterQuestions,
  questionFromJson,
  questionToJson,
  quizPages,
  type ComprehensionQuestion,
} from '../services/storyGenerator';
import { PaletteOverride } from '../theme/ThemeProvider';
import {
  body,
  darkPalette,
  display,
  lightPalette,
  outlineWidthThin,
  radiusButton,
  readingBackground,
  withAlpha,
  type StoryPalette,
} from '../theme/palette';
import { useMounted } from './family';
import { ComprehensionScreen } from './quiz';

// react-native-webview's class typings don't line up with React 19's JSX
// types; the component itself is unchanged.
const WebView = NativeWebView as unknown as React.ComponentType<any>;
type WebViewHandle = { injectJavaScript: (script: string) => void };

type ReaderTheme = 'paper' | 'white' | 'dark';
type Position = { spine: number; fraction: number } | { page: number };

const MARGIN = 22;

/**
 * One chapter as a paginated page: the text flows into screen-wide CSS
 * columns and the view slides one column at a time. Swipes and taps on the
 * left or right edge turn the page; at either end of the chapter it tells the
 * app, which opens the next or previous chapter.
 */
function pageHtml(content: string, opts: { fontSize: number; lineHeight: number; bg: string; fg: string; accent: string; start: string }) {
  return `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
html,body{margin:0;padding:0;height:100%;overflow:hidden;background:${opts.bg};color:${opts.fg};-webkit-text-size-adjust:100%;}
#c{position:absolute;top:${MARGIN}px;left:${MARGIN}px;bottom:${MARGIN}px;width:calc(100vw - ${2 * MARGIN}px);
column-width:calc(100vw - ${2 * MARGIN}px);column-gap:${2 * MARGIN}px;column-fill:auto;
font-size:${opts.fontSize}px;line-height:${opts.lineHeight};font-family:Georgia,'Times New Roman',serif;
transition:transform .22s ease-out;will-change:transform;}
#c *{color:${opts.fg} !important;background:transparent !important;}
img,svg,image{max-width:100%;max-height:calc(100vh - ${2 * MARGIN + 12}px);height:auto;object-fit:contain;display:block;margin:0.4em auto;break-inside:avoid;}
p{margin:0 0 .8em;} h1,h2,h3,h4{line-height:1.25;break-after:avoid;} a{text-decoration:none;}
pre{white-space:pre-wrap;font-family:inherit;}
</style></head><body><div id="c">${content}</div>
<script>
(function(){
  var c=document.getElementById('c'),page=0,pages=1,W=window.innerWidth;
  function post(m){window.ReactNativeWebView.postMessage(JSON.stringify(m));}
  function count(){W=window.innerWidth;pages=Math.max(1,Math.round((c.scrollWidth+${2 * MARGIN})/W));}
  function show(){c.style.transform='translateX('+(-page*W)+'px)';post({type:'page',page:page,pages:pages});}
  window.storyNext=function(){count();if(page<pages-1){page++;show();}else post({type:'edge',dir:'next'});};
  window.storyPrev=function(){count();if(page>0){page--;show();}else post({type:'edge',dir:'prev'});};
  function start(){
    c.style.transition='none';count();
    var s=${JSON.stringify(opts.start)};
    page=s==='last'?pages-1:Math.min(pages-1,Math.max(0,Math.floor(parseFloat(s)*pages+0.0001)));
    show();setTimeout(function(){c.style.transition='';},50);
  }
  var x0=null,y0=null;
  document.addEventListener('touchstart',function(e){x0=e.touches[0].clientX;y0=e.touches[0].clientY;},{passive:true});
  document.addEventListener('touchend',function(e){
    if(x0===null)return;var t=e.changedTouches[0],dx=t.clientX-x0,dy=t.clientY-y0;x0=null;
    if(Math.abs(dx)>40&&Math.abs(dx)>Math.abs(dy)){dx<0?window.storyNext():window.storyPrev();}
    else if(Math.abs(dx)<10&&Math.abs(dy)<10){if(t.clientX<W*0.25)window.storyPrev();else if(t.clientX>W*0.75)window.storyNext();}
  },{passive:true});
  window.addEventListener('resize',function(){var f=pages>1?page/pages:0;count();page=Math.min(pages-1,Math.floor(f*pages));show();});
  if(document.readyState==='complete')start();else window.addEventListener('load',start);
})();
</script></body></html>`;
}

/** The reader: page by page for text books, a picture at a time for picture books. */
export function ReadingScreen({ childId, childName, book }: { childId: string; childName: string; book: Book }) {
  const nav = useNav();
  const toast = useToast();
  const mounted = useMounted();
  const insets = useSafeAreaInsets();
  const [fontSize, setFontSize] = useState(20);
  const [lineHeight, setLineHeight] = useState(1.6);
  const [readerTheme, setReaderTheme] = useState<ReaderTheme>('paper');
  const [epub, setEpub] = useState<EpubBook | null>(null);
  const [pictures, setPictures] = useState<PictureBook | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Text books.
  const [spine, setSpine] = useState(0);
  const [startAt, setStartAt] = useState('0');
  const [html, setHtml] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pages, setPages] = useState(1);
  const [weights, setWeights] = useState<number[] | null>(null);
  const web = useRef<WebViewHandle>(null);

  // Picture books.
  const [picture, setPicture] = useState(0);
  const [pictureUri, setPictureUri] = useState<string | null>(null);

  const session = useRef<number | null>(null);
  const quiz = useRef<ChapterQuizTrigger | null>(null);
  const quizOpen = useRef(false);
  const state = useRef({ spine, page, pages, picture });
  state.current = { spine, page, pages, picture };

  const palette: StoryPalette = readerTheme === 'dark' ? darkPalette : lightPalette;
  const background = readingBackground(readerTheme);

  const startSession = () => {
    session.current = ActivityService.startSession();
  };
  const endSession = useCallback(async () => {
    const start = session.current;
    session.current = null;
    if (start == null) return;
    await ActivityService.logReadingSession(childId, start, book.title, 'epub').catch(() => {});
  }, [book.title, childId]);

  const savePosition = useCallback(() => {
    const s = state.current;
    const position: Position = book.pictureBook
      ? { page: s.picture }
      : { spine: s.spine, fraction: s.pages > 1 ? s.page / s.pages : 0 };
    AsyncStorage.setItem(positionKey(childId, book.id), JSON.stringify(position)).catch(() => {});
  }, [book.id, book.pictureBook, childId]);

  const saveProgress = useCallback(
    (chapter: number, total: number) => {
      BookLibrary.markOpened(childId, book, chapter, total).catch(() => toast.show('Could not update your shelf progress.'));
    },
    [book, childId, toast],
  );

  // Open the book.
  useEffect(() => {
    (async () => {
      try {
        const stored = await AsyncStorage.multiGet(['font_size', 'line_height', 'reader_theme', positionKey(childId, book.id)]);
        const get = (k: string) => stored.find(([key]) => key === k)?.[1];
        const fs = parseFloat(get('font_size') ?? '');
        const lh = parseFloat(get('line_height') ?? '');
        if (!Number.isNaN(fs)) setFontSize(Math.max(14, Math.min(32, fs)));
        if (!Number.isNaN(lh)) setLineHeight(Math.max(1.2, Math.min(2.2, lh)));
        const theme = get('reader_theme');
        if (theme === 'paper' || theme === 'white' || theme === 'dark') setReaderTheme(theme);
        let saved: Position | null = null;
        try {
          saved = JSON.parse(get(positionKey(childId, book.id)) ?? 'null');
        } catch {
          saved = null;
        }

        const file = new File(book.fileUri);
        if (!file.exists || file.size === 0) throw new Error('Empty EPUB');
        const opened = await openEpub(await file.bytes());
        const pictureBook = book.pictureBook ? await readPictureBook(opened) : null;
        if (!mounted.current) return;
        setEpub(opened);
        if (pictureBook) {
          setPictures(pictureBook);
          quiz.current = new ChapterQuizTrigger(pictureBook.chapters.map((c) => ({ title: c.title, depth: c.depth })));
          const p = saved && 'page' in saved ? Math.max(0, Math.min(saved.page, pictureBook.pages.length - 1)) : 0;
          setPicture(p);
          quiz.current.moveTo(chapterIndexOfPicture(pictureBook, p), false);
          saveProgress(p + 1, pictureBook.pages.length);
        } else {
          if (opened.spine.length === 0) throw new Error('No readable EPUB sections');
          quiz.current = new ChapterQuizTrigger(opened.toc.map((e) => ({ title: e.title, depth: e.depth })));
          const s = saved && 'spine' in saved ? Math.max(0, Math.min(saved.spine, opened.spine.length - 1)) : 0;
          setSpine(s);
          setStartAt(saved && 'spine' in saved ? String(saved.fraction) : '0');
          quiz.current.moveTo(tocIndexAt(opened.toc, s), false);
          saveProgress(s + 1, opened.spine.length);
          // How much text each section holds, for "% read".
          (async () => {
            const lengths: number[] = [];
            for (const path of opened.spine) {
              const text = (await textOf(opened.zip, path)) ?? '';
              lengths.push(Math.max(1, text.replace(/<[^>]+>/g, '').length));
            }
            if (mounted.current) setWeights(lengths);
          })();
        }
        startSession();
        ActivityService.logEvent(childId, 'book_opened', { title: book.title }).catch(() => {});
      } catch {
        if (mounted.current) setError('Could not open this EPUB. It may be missing, damaged or unsupported.');
      }
    })();
    return () => {
      savePosition();
      endSession();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Load the current section's page.
  useEffect(() => {
    if (!epub || pictures) return;
    let live = true;
    (async () => {
      const content = await chapterHtml(epub, epub.spine[spine]);
      if (live) setHtml(content);
    })();
    return () => {
      live = false;
    };
  }, [epub, pictures, spine]);

  // Load the current picture.
  useEffect(() => {
    if (!epub || !pictures) return;
    let live = true;
    (async () => {
      const path = pictures.pages[picture];
      const data = await base64Of(epub.zip, path);
      if (live) setPictureUri(data ? `data:${mimeOf(path)};base64,${data}` : null);
    })();
    return () => {
      live = false;
    };
  }, [epub, pictures, picture]);

  const toc = epub?.toc ?? [];
  const tocIndex = epub ? tocIndexAt(toc, spine) : null;
  const chapterTitle = pictures
    ? pictureChapterAt(pictures, picture)?.title ?? `Page ${picture + 1} of ${pictures.pages.length}`
    : tocIndex != null
      ? toc[tocIndex].title
      : '';

  const progress = useMemo(() => {
    if (!epub || !weights) return null;
    const total = weights.reduce((a, b) => a + b, 0);
    const before = weights.slice(0, spine).reduce((a, b) => a + b, 0);
    return Math.min(1, (before + weights[spine] * ((page + 1) / Math.max(1, pages))) / total);
  }, [epub, page, pages, spine, weights]);

  const atEnd = !!epub && !pictures && spine === epub.spine.length - 1 && page >= pages - 1;

  /** Writes (or reuses) a chapter's quiz, so rereading doesn't spend Gemini's quota. */
  const cachedQuiz = useCallback(
    async (number: number, write: () => Promise<ComprehensionQuestion[]>) => {
      const key = quizKey(childId, book.id, number);
      try {
        const saved = await AsyncStorage.getItem(key);
        if (saved) return (JSON.parse(saved) as any[]).map(questionFromJson);
      } catch {
        // A damaged entry is just written again.
      }
      const questions = await write();
      await AsyncStorage.setItem(key, JSON.stringify(questions.map(questionToJson))).catch(() => {});
      return questions;
    },
    [book.id, childId],
  );

  const showChapterQuiz = useCallback(
    async (chapter: FinishedChapter, write: () => Promise<ComprehensionQuestion[]>) => {
      if (quizOpen.current || busy || !FamilySettings.ai.aiQuizzes) return;
      quizOpen.current = true;
      savePosition();
      await endSession();
      await nav.push(
        <ComprehensionScreen
          childId={childId}
          childName={childName}
          bookTitle={book.title}
          chapterNumber={chapter.number}
          chapterTitle={chapter.title}
          skippable
          generateQuestions={() => cachedQuiz(chapter.number, write)}
        />,
      );
      quizOpen.current = false;
      if (mounted.current) startSession();
    },
    [book.title, busy, cachedQuiz, childId, childName, endSession, mounted, nav, savePosition],
  );

  /** Moves to another section; [pageTurn] false for a Contents jump. */
  const goToSpine = (index: number, start: string, pageTurn: boolean) => {
    if (!epub || index < 0 || index >= epub.spine.length) return;
    setHtml(null);
    setStartAt(start);
    setSpine(index);
    setPage(0);
    saveProgress(index + 1, epub.spine.length);
    const finished = quiz.current?.moveTo(tocIndexAt(epub.toc, index), pageTurn);
    if (finished) {
      const from = epub.toc[finished.entry].spineIndex ?? 0;
      const next = finished.end < epub.toc.length ? epub.toc[finished.end].spineIndex : null;
      const to = Math.max(from + 1, Math.min(next ?? epub.spine.length, epub.spine.length));
      const paths = epub.spine.slice(from, to);
      showChapterQuiz(finished, async () => {
        const html = await Promise.all(paths.map(async (p) => (await textOf(epub.zip, p)) ?? ''));
        return generateChapterQuestions(book.title, finished.title, html);
      });
    }
  };

  const onMessage = (e: WebViewMessageEvent) => {
    let message: any;
    try {
      message = JSON.parse(e.nativeEvent.data);
    } catch {
      return;
    }
    if (message.type === 'page') {
      setPage(message.page);
      setPages(message.pages);
      state.current = { ...state.current, page: message.page, pages: message.pages };
      savePosition();
    } else if (message.type === 'edge') {
      if (message.dir === 'next') goToSpine(spine + 1, '0', true);
      else goToSpine(spine - 1, 'last', true);
    }
  };

  const turn = (dir: 'next' | 'prev') => web.current?.injectJavaScript(`window.${dir === 'next' ? 'storyNext' : 'storyPrev'}();true;`);

  const goToPicture = (index: number) => {
    if (!pictures || index < 0 || index >= pictures.pages.length || !epub) return;
    setPicture(index);
    state.current = { ...state.current, picture: index };
    savePosition();
    saveProgress(index + 1, pictures.pages.length);
    const finished = quiz.current?.moveTo(chapterIndexOfPicture(pictures, index), true);
    if (finished) {
      const from = pictures.chapters[finished.entry].page;
      const to = finished.end < pictures.chapters.length ? pictures.chapters[finished.end].page : pictures.pages.length;
      const range = pictures.pages.slice(from, Math.max(from + 1, to));
      showChapterQuiz(finished, async () => {
        const jpegs: string[] = [];
        for (const i of quizPages(range.length)) {
          const path = range[i];
          const data = await base64Of(epub.zip, path);
          if (!data) continue;
          try {
            const ref = await ImageManipulator.manipulate(`data:${mimeOf(path)};base64,${data}`, {
              maxWidth: 768,
              maxHeight: 768,
            }).renderAsync();
            const saved = await ref.saveAsync({ format: SaveFormat.JPEG, compress: 0.7, base64: true });
            if (saved.base64) jpegs.push(saved.base64);
          } catch {
            // A page that can't be read is left out.
          }
        }
        if (jpegs.length === 0) throw new Error("Could not read this chapter's pages");
        return generatePictureChapterQuestions(book.title, finished.title, jpegs);
      });
    }
  };

  const finishBook = async () => {
    if (busy || !epub) return;
    setBusy(true);
    savePosition();
    await endSession();
    await ActivityService.logEvent(childId, 'book_finished', { title: book.title }).catch(() => {});
    if (FamilySettings.ai.aiQuizzes) {
      await nav.push(
        <ComprehensionScreen
          childId={childId}
          childName={childName}
          bookTitle={book.title}
          chapterNumber={(pictures ? picture : spine) + 1}
          generateQuestions={async () => {
            const html = await Promise.all(epub.spine.map(async (p) => (await textOf(epub.zip, p)) ?? ''));
            return generateBookQuestions(book.title, html);
          }}
        />,
      );
    }
    if (!mounted.current) return;
    setBusy(false);
    startSession();
  };

  const showContents = async () => {
    if (!epub || toc.length === 0) return;
    const index = await nav.showSheet<number>(
      <PaletteOverride palette={palette}>
        <SheetPanel padded={false}>
          <ScrollView style={{ maxHeight: 480 }} contentContainerStyle={{ padding: 16 }}>
            <Text style={[display(20, palette.ink, 700), { marginBottom: 8 }]}>Contents</Text>
            {toc.map((entry, i) => (
              <View key={i} style={{ paddingLeft: entry.depth * 16 }}>
                <OptionRow label={entry.title} selected={i === tocIndex} onPress={() => nav.pop(i)} />
              </View>
            ))}
          </ScrollView>
        </SheetPanel>
      </PaletteOverride>,
    );
    if (index == null) return;
    const target = toc[index].spineIndex;
    if (target != null) goToSpine(target, '0', false);
  };

  const showSettings = () => {
    nav.showSheet(
      <PaletteOverride palette={palette}>
        <ReaderSettingsSheet
          fontSize={fontSize}
          lineHeight={lineHeight}
          theme={readerTheme}
          onFontSize={(v) => {
            keepPlace();
            setFontSize(v);
            AsyncStorage.setItem('font_size', String(v)).catch(() => {});
          }}
          onLineHeight={(v) => {
            keepPlace();
            setLineHeight(v);
            AsyncStorage.setItem('line_height', String(v)).catch(() => {});
          }}
          onTheme={(t) => {
            keepPlace();
            setReaderTheme(t);
            AsyncStorage.setItem('reader_theme', t).catch(() => {});
          }}
        />
      </PaletteOverride>,
    );
  };

  const settingsKey = `${fontSize}-${lineHeight}-${readerTheme}`;
  const source = useMemo(
    () =>
      html == null
        ? null
        : {
            html: pageHtml(html, {
              fontSize,
              lineHeight,
              bg: background,
              fg: palette.ink,
              accent: palette.action,
              start: startAt,
            }),
          },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [html, settingsKey, startAt],
  );

  /** Changing the type re-lays the section out; keep the place in it. */
  const keepPlace = () => {
    const s = state.current;
    setStartAt(String(s.pages > 1 ? s.page / s.pages : 0));
  };

  const progressBar = (value: number | null) => (
    <View style={{ height: 10, borderRadius: 6, backgroundColor: withAlpha(palette.action, 0.15), overflow: 'hidden', marginTop: 6 }}>
      <View style={{ width: `${(value ?? 0) * 100}%`, height: '100%', backgroundColor: palette.action }} />
    </View>
  );

  return (
    <PaletteOverride palette={palette}>
      <View style={{ flex: 1, backgroundColor: background }}>
        <View style={{ backgroundColor: background, paddingTop: 0 }}>
          <StickerHeader
            title={book.title}
            showBack
            centerTitle={false}
            trailing={
              <>
                {!pictures && toc.length > 0 && <StickerIconButton icon="format-list-bulleted" label="Contents" onPress={showContents} />}
                <StickerIconButton icon="text-fields" label="Reading settings" onPress={showSettings} />
              </>
            }
          />
        </View>
        {error ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
            <Text style={[body(15, palette.ink), { textAlign: 'center' }]}>{error}</Text>
            <Pressable onPress={() => nav.pop()} style={{ padding: 12 }}>
              <Text style={display(16, palette.ink, 700)}>Back to my library</Text>
            </Pressable>
          </View>
        ) : !epub ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <Spinner />
          </View>
        ) : pictures ? (
          <>
            <View style={{ paddingHorizontal: 12, paddingTop: 10 }}>
              <Text numberOfLines={1} style={[body(14, palette.ink, 700), { textAlign: 'center' }]}>
                {chapterTitle}
              </Text>
              {progressBar((picture + 1) / pictures.pages.length)}
            </View>
            <View style={{ flex: 1, flexDirection: 'row' }}>
              {pictureUri ? (
                <Image source={{ uri: pictureUri }} style={{ flex: 1, margin: 12 }} resizeMode="contain" />
              ) : (
                <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                  <Spinner />
                </View>
              )}
              <Pressable style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '30%' }} onPress={() => goToPicture(picture - 1)} />
              <Pressable style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: '30%' }} onPress={() => goToPicture(picture + 1)} />
            </View>
            <TurnBar
              palette={palette}
              bottom={insets.bottom}
              canPrev={picture > 0}
              atEnd={picture === pictures.pages.length - 1}
              busy={busy}
              onPrev={() => goToPicture(picture - 1)}
              onNext={() => goToPicture(picture + 1)}
              onFinish={finishBook}
              label={`Page ${picture + 1} of ${pictures.pages.length}`}
            />
          </>
        ) : (
          <>
            <View style={{ paddingHorizontal: 12, paddingTop: 10 }}>
              <Text numberOfLines={1} style={[body(14, palette.ink, 700), { textAlign: 'center' }]}>
                {[`Page ${page + 1} of ${pages} in this part`, progress == null ? 'Preparing pages…' : `${Math.round(progress * 100)}% read`].join(' · ')}
              </Text>
              {progressBar(progress)}
              <Text numberOfLines={1} style={[body(14, palette.ink), { textAlign: 'center', marginTop: 4 }]}>
                {chapterTitle}
              </Text>
            </View>
            <View style={{ flex: 1 }}>
              {source ? (
                <WebView
                  key={`${spine}-${settingsKey}`}
                  ref={web}
                  originWhitelist={['*']}
                  source={source}
                  onMessage={onMessage}
                  scrollEnabled={false}
                  bounces={false}
                  style={{ flex: 1, backgroundColor: background }}
                  containerStyle={{ backgroundColor: background }}
                  javaScriptEnabled
                />
              ) : (
                <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                  <Spinner />
                </View>
              )}
            </View>
            <TurnBar
              palette={palette}
              bottom={insets.bottom}
              canPrev={spine > 0 || page > 0}
              atEnd={atEnd}
              busy={busy || !source}
              onPrev={() => turn('prev')}
              onNext={() => turn('next')}
              onFinish={finishBook}
              onContents={toc.length > 0 ? showContents : undefined}
            />
          </>
        )}
      </View>
    </PaletteOverride>
  );
}

function chapterIndexOfPicture(book: PictureBook, page: number): number | null {
  const chapter = pictureChapterAt(book, page);
  return chapter ? book.chapters.indexOf(chapter) : null;
}

function TurnBar({
  palette,
  bottom,
  canPrev,
  atEnd,
  busy,
  onPrev,
  onNext,
  onFinish,
  onContents,
  label,
}: {
  palette: StoryPalette;
  bottom: number;
  canPrev: boolean;
  atEnd: boolean;
  busy: boolean;
  onPrev: () => void;
  onNext: () => void;
  onFinish: () => void;
  onContents?: () => void;
  label?: string;
}) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 12, paddingTop: 8, paddingBottom: bottom + 12 }}>
      <Pressable
        onPress={canPrev && !busy ? onPrev : undefined}
        style={{
          flex: 1,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          paddingVertical: 12,
          borderRadius: radiusButton,
          borderWidth: outlineWidthThin,
          borderColor: palette.outline,
          backgroundColor: palette.surface,
          opacity: canPrev && !busy ? 1 : 0.45,
        }}
      >
        <Icon name="chevron-left" color={palette.ink} />
        <Text style={display(16, palette.ink, 700)}>Previous</Text>
      </Pressable>
      {label ? (
        <Text style={body(13, palette.inkMuted, 600)}>{label}</Text>
      ) : onContents ? (
        <Pressable accessibilityLabel="Contents" onPress={onContents} style={{ padding: 6 }}>
          <Icon name="format-list-bulleted" color={palette.ink} />
        </Pressable>
      ) : null}
      <View style={{ flex: 1 }}>
        <StoryButton
          label={atEnd ? 'Finish book' : 'Next'}
          small
          showArrow={!atEnd}
          onPress={busy ? null : atEnd ? onFinish : onNext}
        />
      </View>
    </View>
  );
}

function ReaderSettingsSheet({
  fontSize: initialFont,
  lineHeight: initialLine,
  theme: initialTheme,
  onFontSize,
  onLineHeight,
  onTheme,
}: {
  fontSize: number;
  lineHeight: number;
  theme: ReaderTheme;
  onFontSize: (v: number) => void;
  onLineHeight: (v: number) => void;
  onTheme: (t: ReaderTheme) => void;
}) {
  const [fontSize, setFontSize] = useState(initialFont);
  const [lineHeight, setLineHeight] = useState(initialLine);
  const [theme, setTheme] = useState(initialTheme);
  const palette = theme === 'dark' ? darkPalette : lightPalette;
  const stepper = (label: string, value: string, minus: () => void, plus: () => void) => (
    <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 14 }}>
      <Text style={[body(16, palette.ink, 700), { flex: 1 }]}>
        {label}: {value}
      </Text>
      {[
        ['remove', minus],
        ['add', plus],
      ].map(([icon, onPress]) => (
        <Pressable
          key={icon as string}
          onPress={onPress as () => void}
          style={{
            width: 44,
            height: 44,
            marginLeft: 8,
            borderRadius: 22,
            borderWidth: outlineWidthThin,
            borderColor: palette.outline,
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: palette.surface,
          }}
        >
          <Icon name={icon as 'add' | 'remove'} color={palette.ink} />
        </Pressable>
      ))}
    </View>
  );
  return (
    <PaletteOverride palette={palette}>
      <SheetPanel>
        <Text style={[display(20, palette.ink, 700), { textAlign: 'center' }]}>Reading Settings</Text>
        {stepper(
          'Font Size',
          `${Math.round(fontSize)}`,
          () => {
            const v = Math.max(14, fontSize - 2);
            setFontSize(v);
            onFontSize(v);
          },
          () => {
            const v = Math.min(32, fontSize + 2);
            setFontSize(v);
            onFontSize(v);
          },
        )}
        {stepper(
          'Line Spacing',
          lineHeight.toFixed(1),
          () => {
            const v = Math.max(1.2, Math.round((lineHeight - 0.2) * 10) / 10);
            setLineHeight(v);
            onLineHeight(v);
          },
          () => {
            const v = Math.min(2.2, Math.round((lineHeight + 0.2) * 10) / 10);
            setLineHeight(v);
            onLineHeight(v);
          },
        )}
        <View style={{ flexDirection: 'row', gap: 8, marginTop: 18, flexWrap: 'wrap' }}>
          {(['paper', 'white', 'dark'] as ReaderTheme[]).map((t) => {
            const on = t === theme;
            return (
              <Pressable
                key={t}
                onPress={() => {
                  setTheme(t);
                  onTheme(t);
                }}
                style={{
                  paddingHorizontal: 14,
                  paddingVertical: 9,
                  borderRadius: 18,
                  borderWidth: outlineWidthThin,
                  borderColor: palette.outline,
                  backgroundColor: on ? palette.action : palette.surface,
                }}
              >
                <Text style={body(14, on ? palette.onAction : palette.ink, 700)}>
                  {t[0].toUpperCase() + t.slice(1)} Theme
                </Text>
              </Pressable>
            );
          })}
        </View>
      </SheetPanel>
    </PaletteOverride>
  );
}
