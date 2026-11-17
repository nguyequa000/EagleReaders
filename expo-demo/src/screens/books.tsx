import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';
import React, { useCallback, useEffect, useState } from 'react';
import { Image, Pressable, ScrollView, Text, View } from 'react-native';

import {
  CenterSpinner,
  CheckRow,
  Icon,
  Spinner,
  StickerCard,
  StickerDialog,
  StickerIconButton,
  StickerIconDisc,
  StickerPage,
  StickerTextField,
  StoryButton,
} from '../components/sticker';
import { useToast } from '../components/Toast';
import { useNav } from '../nav/Navigator';
import { BookShelf, sampleBookBytes, type Book } from '../services/bookLibrary';
import { ChildProfileStore, type ChildProfile } from '../services/childProfiles';
import { readEpubInfo, titleFromFileName } from '../services/epub';
import { usePalette } from '../theme/ThemeProvider';
import { body, cardShadow, display, outlineWidth, outlineWidthThin, radiusTile } from '../theme/palette';
import { useMounted } from './family';

/** Larger files are refused up front rather than risking running out of memory. */
const MAX_EPUB_BYTES = 150 * 1024 * 1024;

type Draft = { key: number; name: string; bytes: Uint8Array; title: string; author: string; readers: Set<string> };
let draftKey = 1;

/** A book's cover, or the first letter of its title on a blue tile. */
export function BookCover({ book, letterSize = 64 }: { book: Book; letterSize?: number }) {
  const palette = usePalette();
  const [failed, setFailed] = useState(false);
  if (book.coverUri && !failed) {
    return (
      <Image
        source={{ uri: book.coverUri }}
        style={{ width: '100%', height: '100%' }}
        resizeMode="cover"
        onError={() => setFailed(true)}
      />
    );
  }
  return (
    <View style={{ flex: 1, backgroundColor: palette.tintBlue, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={display(letterSize, palette.ink, 700)}>{book.title.trim().slice(0, 1).toUpperCase()}</Text>
    </View>
  );
}

/**
 * Manage Shelf: the parent imports the family's books once, then chooses
 * which children each one is for, and can rename them.
 */
export function BookShelfScreen() {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const mounted = useMounted();
  const [tab, setTab] = useState<'shelf' | 'import'>('shelf');
  const [books, setBooks] = useState<Book[]>([]);
  const [children, setChildren] = useState<ChildProfile[]>([]);
  const [drafts, setDrafts] = useState<Draft[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const list = await BookShelf.load();
      let kids: ChildProfile[] = [];
      try {
        kids = await ChildProfileStore.load();
      } catch {
        kids = [];
      }
      if (!mounted.current) return;
      setBooks(list);
      setChildren(kids);
      setLoadError(null);
    } catch {
      if (mounted.current) setLoadError('The shelf could not be loaded.');
    } finally {
      if (mounted.current) setLoading(false);
    }
  }, [mounted]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const addDraft = async (name: string, bytes: Uint8Array) => {
    const info = await readEpubInfo(bytes);
    const title = info?.title ?? '';
    setDrafts((d) => [
      ...d,
      {
        key: draftKey++,
        name,
        bytes,
        title: title || titleFromFileName(name),
        author: info?.author ?? '',
        readers: new Set(children.map((c) => c.id)),
      },
    ]);
  };

  const chooseFiles = async (sample = false) => {
    if (busy) return;
    setBusy(true);
    try {
      if (sample) {
        await addDraft('alice_in_wonderland.epub', await sampleBookBytes());
      } else {
        const result = await DocumentPicker.getDocumentAsync({
          type: ['application/epub+zip', 'application/octet-stream'],
          multiple: true,
          copyToCacheDirectory: true,
        });
        if (result.canceled) return;
        for (const asset of result.assets) {
          if (!asset.name.toLowerCase().endsWith('.epub')) {
            toast.show('Please choose an .epub file.');
            continue;
          }
          if ((asset.size ?? 0) > MAX_EPUB_BYTES) {
            toast.show('This book is too large to open.');
            continue;
          }
          const bytes = await new File(asset.uri).bytes();
          if (!bytes.length) {
            toast.show('The selected EPUB is empty or could not be read.');
            continue;
          }
          await addDraft(asset.name, bytes);
        }
      }
    } catch {
      toast.show('Could not read these files. Please try again.');
    } finally {
      if (mounted.current) setBusy(false);
    }
  };

  const addBooks = async () => {
    if (busy) return;
    if (drafts.some((d) => !d.title.trim())) {
      toast.show('Enter a book title.');
      return;
    }
    setBusy(true);
    let added = 0;
    try {
      for (const draft of drafts) {
        await BookShelf.add({
          fileName: draft.name,
          bytes: draft.bytes,
          title: draft.title,
          author: draft.author,
          readers: [...draft.readers],
        });
        added++;
        // Each successful import goes straight away, so a retry doesn't repeat it.
        setDrafts((d) => d.filter((x) => x.key !== draft.key));
      }
      await refresh();
      setTab('shelf');
      toast.show(added === 1 ? 'Book added to your shelf.' : `${added} books added to your shelf.`);
    } catch (e) {
      const message = String((e as Error)?.message ?? '');
      toast.show(
        /EPUB|container|package|sections/i.test(message)
          ? 'Could not open this EPUB. It may be damaged or unsupported.'
          : 'Could not save this book. Please try again.',
      );
      await refresh();
    } finally {
      if (mounted.current) setBusy(false);
    }
  };

  const rename = async (book: Book) => {
    const next = await nav.showDialog<{ title: string; author: string }>(<RenameDialog book={book} />);
    if (!next) return;
    try {
      await BookShelf.rename(book.id, next.title, next.author);
    } catch {
      toast.show('Could not rename this book. Please try again.');
    }
    refresh();
  };

  const chooseReaders = async (book: Book) => {
    if (children.length === 0) {
      toast.show('Add a child first, then you can give them books.');
      return;
    }
    const readers = await nav.showDialog<string[]>(<ReadersDialog book={book} children={children} />);
    if (!readers) return;
    try {
      await BookShelf.setReaders(book.id, readers);
    } catch {
      toast.show('Could not save who reads this book. Please try again.');
    }
    refresh();
  };

  const remove = async (book: Book) => {
    const ok = await nav.showDialog<boolean>(
      <StickerDialog
        title="Remove book?"
        actions={[
          { label: 'Cancel', onPress: () => nav.pop(false) },
          { label: 'Remove', onPress: () => nav.pop(true) },
        ]}
      >
        <Text style={body(15, palette.ink)}>
          Remove "{book.title}" from the shelf? Every child it was given to loses it, and their place in it.
        </Text>
      </StickerDialog>,
    );
    if (!ok) return;
    try {
      await BookShelf.remove(book);
    } catch {
      toast.show('Could not completely remove this book. Please try again.');
    }
    refresh();
  };

  const readersLabel = (book: Book) => {
    const names = children.filter((c) => book.readers.includes(c.id)).map((c) => c.name);
    return names.length === 0 ? 'Not given to anyone yet' : `For ${names.join(', ')}`;
  };

  const shelfTab = loading ? (
    <CenterSpinner />
  ) : loadError ? (
    <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={body(15, palette.ink)}>{loadError}</Text>
      <Pressable onPress={refresh} style={{ padding: 12 }}>
        <Text style={display(16, palette.ink, 700)}>Try again</Text>
      </Pressable>
    </View>
  ) : books.length === 0 ? (
    <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', padding: 32, alignItems: 'center' }}>
      <StickerIconDisc icon="auto-stories" color={palette.tintGreen} size={96} />
      <Text style={[display(24, palette.ink, 700), { textAlign: 'center', marginTop: 20 }]}>Your next adventure starts here</Text>
      <Text style={[body(15, palette.ink), { textAlign: 'center', marginTop: 12 }]}>
        Import EPUB books, then choose which children each one is for.
      </Text>
      <View style={{ height: 24 }} />
      <StoryButton label="Import the first book" showArrow={false} onPress={() => setTab('import')} style={{ alignSelf: 'stretch' }} />
    </ScrollView>
  ) : (
    <ScrollView contentContainerStyle={{ padding: 20, flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 16 }}>
      {books.map((book) => (
        <View key={book.id} style={{ width: '47%' }}>
          <Pressable onPress={() => chooseReaders(book)} onLongPress={() => remove(book)}>
            <View
              style={{
                backgroundColor: palette.surface,
                borderRadius: radiusTile,
                borderWidth: outlineWidth,
                borderColor: palette.outline,
                padding: 10,
                ...cardShadow(palette),
              }}
            >
              <View style={{ aspectRatio: 0.7, borderRadius: 12, overflow: 'hidden' }}>
                <BookCover book={book} />
              </View>
              <Text numberOfLines={2} style={[display(16, palette.ink, 700), { marginTop: 10 }]}>
                {book.title}
              </Text>
              {book.author ? (
                <Text numberOfLines={1} style={body(13, palette.inkMuted)}>
                  {book.author}
                </Text>
              ) : null}
              <Text numberOfLines={1} style={body(12, palette.ink, 700)}>
                {readersLabel(book)}
              </Text>
              <View style={{ flexDirection: 'row', justifyContent: 'flex-end', marginTop: 4 }}>
                <Pressable accessibilityLabel={`Rename ${book.title}`} onPress={() => rename(book)} style={{ padding: 6 }}>
                  <Icon name="edit" color={palette.ink} />
                </Pressable>
                <Pressable accessibilityLabel={`Choose who reads ${book.title}`} onPress={() => chooseReaders(book)} style={{ padding: 6 }}>
                  <Icon name="group" color={palette.ink} />
                </Pressable>
                <Pressable accessibilityLabel={`Remove ${book.title}`} onPress={() => remove(book)} style={{ padding: 6 }}>
                  <Icon name="delete-outline" color={palette.ink} />
                </Pressable>
              </View>
            </View>
          </Pressable>
        </View>
      ))}
    </ScrollView>
  );

  const importTab = (
    <ScrollView contentContainerStyle={{ padding: 24 }} keyboardShouldPersistTaps="handled">
      <Text style={display(26, palette.ink, 700)}>Fill the family shelf</Text>
      <Text style={[body(15, palette.inkMuted), { marginTop: 8 }]}>
        Choose EPUB files from your phone. Check each title and author, and who it is for, before adding them.
      </Text>
      <View style={{ height: 24 }} />
      <StoryButton label="Choose File" showArrow={false} onPress={busy ? null : () => chooseFiles()} />
      <View style={{ height: 12 }} />
      <StoryButton
        label="Try sample: Alice's Adventures in Wonderland"
        filled={false}
        showArrow={false}
        onPress={busy ? null : () => chooseFiles(true)}
      />
      {drafts.map((draft) => (
        <View key={draft.key} style={{ marginTop: 20 }}>
          <StickerCard padding={16}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Text numberOfLines={1} style={[body(14, palette.inkMuted, 600), { flex: 1 }]}>
                {draft.name}
              </Text>
              <Pressable
                accessibilityLabel={`Discard ${draft.name}`}
                disabled={busy}
                onPress={() => setDrafts((d) => d.filter((x) => x.key !== draft.key))}
                style={{ padding: 6 }}
              >
                <Icon name="close" color={palette.ink} />
              </Pressable>
            </View>
            <StickerTextField
              label="Book title"
              value={draft.title}
              editable={!busy}
              shadow={false}
              error={draft.title.trim() ? null : 'Enter a book title.'}
              onChangeText={(t) => setDrafts((d) => d.map((x) => (x.key === draft.key ? { ...x, title: t } : x)))}
            />
            <View style={{ height: 12 }} />
            <StickerTextField
              label="Author (optional)"
              value={draft.author}
              editable={!busy}
              shadow={false}
              onChangeText={(t) => setDrafts((d) => d.map((x) => (x.key === draft.key ? { ...x, author: t } : x)))}
            />
            <Text style={[body(15, palette.ink, 700), { marginTop: 16, marginBottom: 8 }]}>Who is it for?</Text>
            {children.length === 0 ? (
              <Text style={body(14, palette.inkMuted)}>No children yet. You can give it to them once they are added.</Text>
            ) : (
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {children.map((child) => {
                  const on = draft.readers.has(child.id);
                  return (
                    <Pressable
                      key={child.id}
                      disabled={busy}
                      accessibilityRole="checkbox"
                      accessibilityState={{ checked: on }}
                      onPress={() =>
                        setDrafts((d) =>
                          d.map((x) => {
                            if (x.key !== draft.key) return x;
                            const readers = new Set(x.readers);
                            if (on) readers.delete(child.id);
                            else readers.add(child.id);
                            return { ...x, readers };
                          }),
                        )
                      }
                      style={{
                        flexDirection: 'row',
                        alignItems: 'center',
                        paddingHorizontal: 12,
                        paddingVertical: 8,
                        borderRadius: 18,
                        borderWidth: outlineWidthThin,
                        borderColor: palette.outline,
                        backgroundColor: on ? palette.action : palette.surface,
                      }}
                    >
                      {on && <Icon name="check" size={16} color={palette.onAction} />}
                      <Text style={[body(14, on ? palette.onAction : palette.ink, 700), { marginLeft: on ? 4 : 0 }]}>{child.name}</Text>
                    </Pressable>
                  );
                })}
              </View>
            )}
          </StickerCard>
        </View>
      ))}
      {drafts.length > 0 && (
        <View style={{ marginTop: 24 }}>
          <StoryButton label="Add to shelf" showArrow={false} onPress={busy ? null : addBooks} />
        </View>
      )}
      {busy && (
        <View style={{ padding: 24 }}>
          <Spinner />
        </View>
      )}
    </ScrollView>
  );

  return (
    <StickerPage title="Manage Shelf" forParent>
      <View style={{ flexDirection: 'row', borderBottomWidth: 1.5, borderBottomColor: palette.outline }}>
        {(['shelf', 'import'] as const).map((t) => {
          const on = tab === t;
          return (
            <Pressable
              key={t}
              onPress={() => setTab(t)}
              accessibilityRole="tab"
              accessibilityState={{ selected: on }}
              style={{
                flex: 1,
                alignItems: 'center',
                paddingVertical: 10,
                borderBottomWidth: 3,
                borderBottomColor: on ? palette.action : 'transparent',
              }}
            >
              <Icon name={t === 'shelf' ? 'menu-book' : 'add-circle-outline'} color={on ? palette.ink : palette.inkMuted} />
              <Text style={display(16, on ? palette.ink : palette.inkMuted, 700)}>{t === 'shelf' ? 'Shelf' : 'Import'}</Text>
            </Pressable>
          );
        })}
      </View>
      <View style={{ flex: 1 }}>{tab === 'shelf' ? shelfTab : importTab}</View>
    </StickerPage>
  );
}

function RenameDialog({ book }: { book: Book }) {
  const nav = useNav();
  const [title, setTitle] = useState(book.title);
  const [author, setAuthor] = useState(book.author);
  return (
    <StickerDialog
      title="Rename book"
      actions={[
        { label: 'Cancel', onPress: () => nav.pop() },
        { label: 'Save', onPress: title.trim() ? () => nav.pop({ title, author }) : null },
      ]}
    >
      <StickerTextField label="Book title" value={title} onChangeText={setTitle} autoFocus shadow={false} error={title.trim() ? null : 'Enter a book title.'} />
      <View style={{ height: 16 }} />
      <StickerTextField label="Author (optional)" value={author} onChangeText={setAuthor} shadow={false} />
    </StickerDialog>
  );
}

function ReadersDialog({ book, children }: { book: Book; children: ChildProfile[] }) {
  const nav = useNav();
  const [readers, setReaders] = useState(new Set(book.readers));
  return (
    <StickerDialog
      title={`Who is "${book.title}" for?`}
      actions={[
        { label: 'Cancel', onPress: () => nav.pop() },
        { label: 'Save', onPress: () => nav.pop([...readers]) },
      ]}
    >
      <ScrollView style={{ maxHeight: 320 }}>
        {children.map((child) => (
          <CheckRow
            key={child.id}
            label={child.name}
            value={readers.has(child.id)}
            leading={<Text style={{ fontSize: 24 }}>{child.emoji}</Text>}
            onChange={(on) =>
              setReaders((r) => {
                const next = new Set(r);
                if (on) next.add(child.id);
                else next.delete(child.id);
                return next;
              })
            }
          />
        ))}
      </ScrollView>
    </StickerDialog>
  );
}

/** One child's books, chosen from the family shelf (Child Profile → Choose books). */
export function ChildShelfScreen({ childId, childName }: { childId: string; childName: string }) {
  const palette = usePalette();
  const nav = useNav();
  const toast = useToast();
  const [books, setBooks] = useState<Book[] | null>(null);

  const refresh = useCallback(async () => {
    try {
      setBooks(await BookShelf.load());
    } catch {
      setBooks([]);
    }
  }, []);
  useEffect(() => {
    refresh();
  }, [refresh]);

  const toggle = async (book: Book, on: boolean) => {
    try {
      await BookShelf.setReaders(book.id, [...book.readers.filter((id) => id !== childId), ...(on ? [childId] : [])]);
    } catch {
      toast.show('Could not save. Please try again.');
    }
    refresh();
  };

  const manageShelf = async () => {
    await nav.push(<BookShelfScreen />);
    refresh();
  };

  return (
    <StickerPage
      title={`${childName}'s Books`}
      forParent
      actions={<StickerIconButton icon="library-add" label="Manage Shelf" onPress={manageShelf} />}
    >
      {books == null ? (
        <CenterSpinner />
      ) : books.length === 0 ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32 }}>
          <Text style={display(20, palette.ink, 700)}>The family shelf is empty.</Text>
          <Text style={[body(15, palette.ink), { textAlign: 'center', marginTop: 12 }]}>
            Import books in Manage Shelf, then tick the ones for this child here.
          </Text>
          <View style={{ height: 24 }} />
          <StoryButton label="Import books" showArrow={false} onPress={manageShelf} style={{ alignSelf: 'stretch' }} />
        </View>
      ) : (
        <ScrollView contentContainerStyle={{ paddingVertical: 8, paddingHorizontal: 16 }}>
          <Text style={[body(15, palette.ink), { marginVertical: 8 }]}>Tick the books {childName} can read.</Text>
          {books.map((book) => (
            <CheckRow
              key={book.id}
              label={book.title}
              subtitle={book.author || undefined}
              value={book.readers.includes(childId)}
              onChange={(on) => toggle(book, on)}
              leading={
                <View style={{ width: 40, height: 56, borderRadius: 6, overflow: 'hidden', borderWidth: 1, borderColor: palette.outline }}>
                  <BookCover book={book} letterSize={22} />
                </View>
              }
            />
          ))}
        </ScrollView>
      )}
    </StickerPage>
  );
}
