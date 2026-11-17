import JSZip from 'jszip';

/**
 * A pure-JS EPUB reader (Expo Go has no native EPUB module): unzips the book,
 * reads the package document, spine and contents, and finds the cover. Ported
 * from the Flutter app's epub_metadata.dart, epub_cover.dart and
 * picture_book_view.dart, which parse the same files with regexes.
 */

export type ManifestItem = { id: string; href: string; mediaType: string; properties: string };

export type TocEntry = {
  title: string;
  /** Full path inside the zip, without the #fragment. */
  path: string;
  depth: number;
  /** Index into the spine, or null when the entry's file isn't in it. */
  spineIndex: number | null;
};

export type EpubBook = {
  zip: JSZip;
  title: string;
  author: string;
  manifest: ManifestItem[];
  /** Reading-order files, as full paths inside the zip. */
  spine: string[];
  toc: TocEntry[];
  coverPath: string | null;
};

export async function openEpub(bytes: Uint8Array): Promise<EpubBook> {
  const zip = await JSZip.loadAsync(bytes);
  const container = await textOf(zip, 'META-INF/container.xml');
  if (!container) throw new Error('Not an EPUB (no container.xml)');
  const opfPath = /full-path\s*=\s*["']([^"']+)["']/.exec(container)?.[1];
  if (!opfPath) throw new Error('No package document');
  const opf = await textOf(zip, opfPath);
  if (!opf) throw new Error('Missing package document');
  const base = dirOf(opfPath);

  const manifest: ManifestItem[] = [];
  for (const m of opf.matchAll(/<(?:\w+:)?item\b[^>]*>/g)) {
    const a = attributes(m[0]);
    if (!a.id || !a.href) continue;
    manifest.push({
      id: a.id,
      href: resolve(base, safeDecode(a.href)),
      mediaType: a['media-type'] ?? '',
      properties: a.properties ?? '',
    });
  }
  const byId = new Map(manifest.map((i) => [i.id, i]));

  const spineTag = /<(?:\w+:)?spine\b[^>]*>/.exec(opf)?.[0] ?? '';
  const spine: string[] = [];
  for (const m of opf.matchAll(/<(?:\w+:)?itemref\b[^>]*>/g)) {
    const item = byId.get(attributes(m[0]).idref ?? '');
    if (item) spine.push(item.href);
  }

  const info = infoFromOpf(opf);
  let toc: TocEntry[] = [];
  try {
    const nav = manifest.find((i) => i.properties.split(/\s+/).includes('nav'));
    const ncxId = attributes(spineTag).toc;
    const ncx = (ncxId ? byId.get(ncxId) : undefined) ?? manifest.find((i) => i.mediaType === 'application/x-dtbncx+xml');
    if (nav) toc = parseNav((await textOf(zip, nav.href)) ?? '', dirOf(nav.href));
    if (toc.length === 0 && ncx) toc = parseNcx((await textOf(zip, ncx.href)) ?? '', dirOf(ncx.href));
  } catch {
    toc = [];
  }
  toc = toc.map((e) => ({ ...e, spineIndex: spineIndexOf(e.path, spine) }));

  return {
    zip,
    title: info.title,
    author: info.author,
    manifest,
    spine,
    toc,
    coverPath: coverPathOf(opf, manifest),
  };
}

/** The first dc:title and dc:creator in an OPF package document. */
function infoFromOpf(opf: string): { title: string; author: string } {
  const metadata = /<(?:\w+:)?metadata\b[\s\S]*?<\/(?:\w+:)?metadata>/i.exec(opf)?.[0] ?? opf;
  const first = (el: string) =>
    plain(new RegExp(`<(?:\\w+:)?${el}\\b[^>]*>([\\s\\S]*?)</(?:\\w+:)?${el}>`, 'i').exec(metadata)?.[1]);
  return { title: first('title'), author: first('creator') };
}

/** Title and author without opening the whole book, for the import form. */
export async function readEpubInfo(bytes: Uint8Array): Promise<{ title: string; author: string } | null> {
  try {
    const book = await openEpub(bytes);
    return { title: book.title, author: book.author };
  } catch {
    return null;
  }
}

/**
 * The cover image: the manifest item marked cover-image (EPUB 3), the one
 * named by <meta name="cover"> (EPUB 2), or an image called "cover".
 */
function coverPathOf(opf: string, manifest: ManifestItem[]): string | null {
  const isImage = (i: ManifestItem) => i.mediaType.startsWith('image/');
  const marked = manifest.find((i) => isImage(i) && i.properties.split(/\s+/).includes('cover-image'));
  if (marked) return marked.href;
  for (const m of opf.matchAll(/<(?:\w+:)?meta\b[^>]*>/g)) {
    const a = attributes(m[0]);
    if (a.name?.toLowerCase() !== 'cover') continue;
    const id = a.content?.toLowerCase();
    const item = manifest.find((i) => i.id.toLowerCase() === id && isImage(i));
    if (item) return item.href;
  }
  return manifest.find((i) => isImage(i) && `${i.id} ${i.href}`.toLowerCase().includes('cover'))?.href ?? null;
}

/** An EPUB 3 navigation document's table of contents. */
function parseNav(html: string, base: string): TocEntry[] {
  const nav =
    /<nav\b[^>]*epub:type\s*=\s*["'][^"']*\btoc\b[^"']*["'][^>]*>([\s\S]*?)<\/nav>/i.exec(html)?.[1] ??
    /<nav\b[^>]*>([\s\S]*?)<\/nav>/i.exec(html)?.[1] ??
    '';
  const out: TocEntry[] = [];
  let depth = 0;
  const tokens = /<(\/?)(ol|a)\b([^>]*)>|<\/a>/gi;
  let match: RegExpExecArray | null;
  while ((match = tokens.exec(nav))) {
    const closing = match[1] === '/';
    const tag = (match[2] ?? 'a').toLowerCase();
    if (tag === 'ol') {
      depth += closing ? -1 : 1;
    } else if (!closing && match[0].toLowerCase() !== '</a>') {
      const href = attributes(match[0]).href;
      const end = nav.indexOf('</a>', tokens.lastIndex);
      const label = plain(nav.slice(tokens.lastIndex, end < 0 ? undefined : end));
      if (href && label) {
        out.push({ title: label, path: resolve(base, safeDecode(href.split('#')[0])), depth: Math.max(0, depth - 1), spineIndex: null });
      }
    }
  }
  return out;
}

/** An EPUB 2 NCX's navPoints, nested. */
function parseNcx(xml: string, base: string): TocEntry[] {
  const out: TocEntry[] = [];
  let depth = 0;
  let pendingTitle: string | null = null;
  const tokens = /<(\/?)(navPoint|text|content)\b([^>]*?)(\/?)>/gi;
  let match: RegExpExecArray | null;
  while ((match = tokens.exec(xml))) {
    const closing = match[1] === '/';
    const tag = match[2].toLowerCase();
    if (tag === 'navpoint') {
      if (closing) depth--;
      else {
        depth++;
        pendingTitle = null;
      }
    } else if (tag === 'text' && !closing) {
      const end = xml.indexOf('</', tokens.lastIndex);
      pendingTitle = plain(xml.slice(tokens.lastIndex, end));
    } else if (tag === 'content' && !closing && pendingTitle != null) {
      const src = attributes(match[0]).src;
      if (src && pendingTitle) {
        out.push({ title: pendingTitle, path: resolve(base, safeDecode(src.split('#')[0])), depth: Math.max(0, depth - 1), spineIndex: null });
      }
      pendingTitle = null;
    }
  }
  return out;
}

function spineIndexOf(path: string, spine: string[]): number | null {
  if (!path) return null;
  for (let i = 0; i < spine.length; i++) {
    const item = spine[i];
    if (item === path || item.endsWith(`/${path}`) || path.endsWith(`/${item}`)) return i;
  }
  return null;
}

/** The contents entry a spine position belongs to: the latest at or before it. */
export function tocIndexAt(toc: TocEntry[], spineIndex: number): number | null {
  let found: number | null = null;
  toc.forEach((entry, i) => {
    const start = entry.spineIndex;
    if (start != null && start <= spineIndex && start >= (found == null ? 0 : toc[found].spineIndex ?? 0)) {
      found = i;
    }
  });
  return found;
}

export async function textOf(zip: JSZip, path: string): Promise<string | null> {
  const file = zip.file(path) ?? zip.file(safeDecode(path));
  return file ? file.async('string') : null;
}

export async function base64Of(zip: JSZip, path: string): Promise<string | null> {
  const file = zip.file(path) ?? zip.file(safeDecode(path));
  return file ? file.async('base64') : null;
}

export async function bytesOf(zip: JSZip, path: string): Promise<Uint8Array | null> {
  const file = zip.file(path) ?? zip.file(safeDecode(path));
  return file ? file.async('uint8array') : null;
}

export function mimeOf(path: string): string {
  const ext = path.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'svg':
      return 'image/svg+xml';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

const IMG_SRC = /<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']/i;
const SVG_IMAGE = /<image\b[^>]*?\b(?:xlink:)?href\s*=\s*["']([^"']+)["']/i;
const HEAD_OR_STYLE = /<(head|style|script)\b[\s\S]*?<\/\1>/gi;

export type PictureBook = {
  /** Each page's image path inside the zip, in reading order. */
  pages: string[];
  chapters: { title: string; page: number; depth: number }[];
};

/**
 * The book as a picture book (comic, fixed-layout scan) or null when it is an
 * ordinary text book: nearly every spine page is a single image with next to
 * no text.
 */
export async function readPictureBook(book: EpubBook): Promise<PictureBook | null> {
  let textPages = 0;
  const pages: string[] = [];
  const pageAt = new Map<string, number>();
  for (const path of book.spine) {
    const content = await textOf(book.zip, path);
    if (content == null) continue;
    if (!pageAt.has(path)) pageAt.set(path, pages.length);
    const bodyHtml = content.replace(HEAD_OR_STYLE, ' ');
    const text = bodyHtml.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ');
    if (text.trim().length > 40) {
      textPages++;
      continue;
    }
    const src = (IMG_SRC.exec(bodyHtml) ?? SVG_IMAGE.exec(bodyHtml))?.[1];
    if (!src) continue;
    const image = resolve(dirOf(path), safeDecode(src));
    if (book.zip.file(image)) pages.push(image);
  }
  if (pages.length < 2 || textPages * 10 > pages.length) return null;
  const chapters = book.toc
    .map((e) => ({ title: e.title, page: pageAt.get(e.path), depth: e.depth }))
    .filter((c): c is { title: string; page: number; depth: number } => c.page != null)
    .map((c) => ({ ...c, page: Math.min(c.page, pages.length - 1) }));
  return { pages, chapters };
}

/** The picture-book chapter [page] belongs to. */
export function pictureChapterAt(book: PictureBook, page: number) {
  let found: PictureBook['chapters'][number] | null = null;
  for (const c of book.chapters) {
    if (c.page <= page && c.page >= (found?.page ?? 0)) found = c;
  }
  return found;
}

/**
 * One spine file as a self-contained page for the reader's web view: the
 * body only (the book's own stylesheets are left out so the reader's colours
 * and sizes win), with every picture inlined as a data URI.
 */
export async function chapterHtml(book: EpubBook, path: string): Promise<string> {
  const raw = (await textOf(book.zip, path)) ?? '';
  let bodyHtml = /<body\b[^>]*>([\s\S]*)<\/body>/i.exec(raw)?.[1] ?? raw;
  bodyHtml = bodyHtml.replace(/<script\b[\s\S]*?<\/script>/gi, '').replace(/<link\b[^>]*>/gi, '');
  const dir = dirOf(path);
  const sources = new Set<string>();
  for (const m of bodyHtml.matchAll(/\b(src|xlink:href|href)\s*=\s*["']([^"']+\.(?:jpe?g|png|gif|svg|webp))["']/gi)) {
    sources.add(m[2]);
  }
  for (const src of sources) {
    const target = resolve(dir, safeDecode(src));
    const data = await base64Of(book.zip, target);
    if (!data) continue;
    const uri = `data:${mimeOf(target)};base64,${data}`;
    bodyHtml = bodyHtml.split(`"${src}"`).join(`"${uri}"`).split(`'${src}'`).join(`'${uri}'`);
  }
  return bodyHtml;
}

/** A readable title made from a file name: alice_in_wonderland.epub -> "Alice In Wonderland". */
export function titleFromFileName(fileName: string): string {
  const name = fileName
    .split(/[/\\]/)
    .pop()!
    .replace(/\.epub$/i, '')
    .replace(/[_.\-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!name) return fileName;
  return name
    .split(' ')
    .map((w) => (w === w.toLowerCase() ? w[0].toUpperCase() + w.slice(1) : w))
    .join(' ');
}

function attributes(tag: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const m of tag.matchAll(/([\w:-]+)\s*=\s*("([^"]*)"|'([^']*)')/g)) {
    out[m[1].toLowerCase()] = m[3] ?? m[4] ?? '';
  }
  return out;
}

/** XML as plain text: tags dropped, entities decoded, spaces collapsed. */
function plain(xml: string | undefined): string {
  return (xml ?? '')
    .replace(/<!\[CDATA\[|\]\]>/g, '')
    .replace(/<[^>]*>/g, '')
    .replace(/&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);/g, (_, code: string) => {
      switch (code) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
        default:
          return String.fromCharCode(
            code.startsWith('#x') ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10),
          );
      }
    })
    .replace(/\s+/g, ' ')
    .trim();
}

function dirOf(path: string): string {
  const i = path.lastIndexOf('/');
  return i < 0 ? '' : path.slice(0, i + 1);
}

/** [href] relative to [base], with `..` and `.` resolved. */
function resolve(base: string, href: string): string {
  if (/^[a-z]+:/i.test(href)) return href;
  const parts: string[] = [];
  for (const part of (href.startsWith('/') ? href.slice(1) : `${base}${href}`).split('/')) {
    if (part === '..') parts.pop();
    else if (part && part !== '.') parts.push(part);
  }
  return parts.join('/');
}

function safeDecode(path: string): string {
  try {
    return decodeURIComponent(path);
  } catch {
    return path;
  }
}
