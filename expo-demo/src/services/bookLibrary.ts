import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Crypto from 'expo-crypto';
import { Directory, File, Paths } from 'expo-file-system';

import { bytesOf, openEpub, readPictureBook } from './epub';

/**
 * The family's books on this device: imported once in Manage Shelf, then
 * given to the children who should read them. Like the Flutter app, books
 * live on the device rather than in Firestore; how far each child has got is
 * kept apart from the book, per child.
 */
export type Book = {
  id: string;
  title: string;
  author: string;
  /** file:// URI of the EPUB. */
  fileUri: string;
  coverUri: string | null;
  addedAt: number;
  readers: string[];
  pictureBook: boolean;
  // Per child, filled in by BookLibrary.load().
  chapter: number;
  chaptersTotal: number;
  lastOpenedAt: number | null;
};

type Progress = { chapter: number; chaptersTotal: number; lastOpenedAt: number | null };

const SHELF_KEY = 'book_shelf';
const progressKey = (childId: string) => `book_progress_${childId}`;
export const positionKey = (childId: string, bookId: string) => `epub_position_${childId}_${bookId}`;
export const quizKey = (childId: string, bookId: string, chapter: number) =>
  `chapter_quiz_${childId}_${bookId}_${chapter}`;

// Reader callbacks and shelf actions can't clobber each other's
// read-modify-write updates.
let pending: Promise<unknown> = Promise.resolve();
function serial<T>(action: () => Promise<T>): Promise<T> {
  const next = pending.then(action, action);
  pending = next.catch(() => {});
  return next;
}

async function readShelf(): Promise<Book[]> {
  const raw = await AsyncStorage.getItem(SHELF_KEY);
  const list = raw ? (JSON.parse(raw) as Book[]) : [];
  // A file that has gone (the app reinstalled) is no book at all.
  return list.filter((b) => new File(b.fileUri).exists);
}

async function writeShelf(books: Book[]): Promise<void> {
  const plain = books.map(({ chapter, chaptersTotal, lastOpenedAt, ...rest }) => ({
    ...rest,
    chapter: 0,
    chaptersTotal: 0,
    lastOpenedAt: null,
  }));
  await AsyncStorage.setItem(SHELF_KEY, JSON.stringify(plain));
}

async function readProgress(childId: string): Promise<Record<string, Progress>> {
  const raw = await AsyncStorage.getItem(progressKey(childId));
  return raw ? JSON.parse(raw) : {};
}

function freeId(books: Book[], id: string): string {
  const stem = id.toLowerCase().endsWith('.epub') ? id.slice(0, -5) : id;
  let free = id;
  for (let n = 2; books.some((b) => b.id === free); n++) free = `${stem}-${n}.epub`;
  return free;
}

function shelfDir(): Directory {
  const dir = new Directory(Paths.document, 'books', 'shelf');
  dir.create({ intermediates: true, idempotent: true });
  return dir;
}

async function forget(childId: string, bookId: string) {
  const keys = await AsyncStorage.getAllKeys();
  const prefix = `chapter_quiz_${childId}_${bookId}_`;
  await AsyncStorage.multiRemove([positionKey(childId, bookId), ...keys.filter((k) => k.startsWith(prefix))]);
  const progress = await readProgress(childId);
  if (progress[bookId]) {
    delete progress[bookId];
    await AsyncStorage.setItem(progressKey(childId), JSON.stringify(progress));
  }
}

export const BookShelf = {
  /** Every book, newest first. */
  load: () => serial(async () => (await readShelf()).sort((a, b) => b.addedAt - a.addedAt)),

  add: (opts: { fileName: string; bytes: Uint8Array; title: string; author?: string; readers: string[] }) =>
    serial(async () => {
      if (!opts.fileName.toLowerCase().endsWith('.epub')) throw new Error('Please choose an .epub file.');
      if (!opts.title.trim()) throw new Error('Enter a book title.');
      const epub = await openEpub(opts.bytes);
      if (epub.spine.length === 0) throw new Error('No readable EPUB sections');
      const pictures = (await readPictureBook(epub)) != null;
      const books = await readShelf();
      const id = freeId(books, opts.fileName.split(/[/\\]/).pop()!);
      const stem = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, id);
      const dir = shelfDir();
      const file = new File(dir, `${stem}.epub`);
      file.create({ overwrite: true });
      await file.write(opts.bytes);
      let coverUri: string | null = null;
      if (epub.coverPath) {
        const cover = await bytesOf(epub.zip, epub.coverPath);
        if (cover && cover.length) {
          const ext = epub.coverPath.split('.').pop()?.toLowerCase() ?? 'img';
          const coverFile = new File(dir, `${stem}.cover.${ext}`);
          coverFile.create({ overwrite: true });
          await coverFile.write(cover);
          coverUri = coverFile.uri;
        }
      }
      const book: Book = {
        id,
        title: opts.title.trim(),
        author: (opts.author ?? '').trim(),
        fileUri: file.uri,
        coverUri,
        addedAt: Date.now(),
        readers: [...new Set(opts.readers)],
        pictureBook: pictures,
        chapter: 0,
        chaptersTotal: 0,
        lastOpenedAt: null,
      };
      await writeShelf([...books, book]);
      return book;
    }),

  rename: (id: string, title: string, author: string) =>
    serial(async () => {
      if (!title.trim()) throw new Error('Enter a book title.');
      const books = await readShelf();
      await writeShelf(books.map((b) => (b.id === id ? { ...b, title: title.trim(), author: author.trim() } : b)));
    }),

  /** Puts the book on exactly these children's shelves. */
  setReaders: (id: string, readers: string[]) =>
    serial(async () => {
      const books = await readShelf();
      await writeShelf(books.map((b) => (b.id === id ? { ...b, readers: [...new Set(readers)] } : b)));
    }),

  /** Takes the book off every child's shelf and deletes it. */
  remove: (book: Book) =>
    serial(async () => {
      const books = await readShelf();
      for (const uri of [book.fileUri, book.coverUri]) {
        if (!uri) continue;
        try {
          const f = new File(uri);
          if (f.exists) f.delete();
        } catch {
          // Already gone.
        }
      }
      const keys = await AsyncStorage.getAllKeys();
      const children = new Set([
        ...book.readers,
        ...keys.filter((k) => k.startsWith('book_progress_')).map((k) => k.slice('book_progress_'.length)),
      ]);
      for (const child of children) await forget(child, book.id);
      await writeShelf(books.filter((b) => b.id !== book.id));
    }),
};

/** One child's shelf: the family's books given to [childId], with their progress. */
export const BookLibrary = {
  load: (childId: string) =>
    serial(async () => {
      const books = await readShelf();
      const progress = await readProgress(childId);
      return books
        .filter((b) => b.readers.includes(childId))
        .map((b): Book => Object.assign({}, b, { chapter: 0, chaptersTotal: 0, lastOpenedAt: null }, progress[b.id]));
    }),

  markOpened: (childId: string, book: Book, chapter: number, total: number) =>
    serial(async () => {
      if (total < 1) return;
      const progress = await readProgress(childId);
      progress[book.id] = {
        chapter: Math.max(1, Math.min(total, chapter)),
        chaptersTotal: total,
        lastOpenedAt: Date.now(),
      };
      await AsyncStorage.setItem(progressKey(childId), JSON.stringify(progress));
    }),
};

/** The bundled sample, as the bytes "Try sample" imports. */
export async function sampleBookBytes(): Promise<Uint8Array> {
  const { Asset } = await import('expo-asset');
  const asset = Asset.fromModule(require('../../assets/books/alice_in_wonderland.epub'));
  await asset.downloadAsync();
  return new File(asset.localUri ?? asset.uri).bytes();
}
