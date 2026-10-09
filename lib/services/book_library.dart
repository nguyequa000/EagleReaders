import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:epub_view/epub_view.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'epub_cover.dart';
import 'lighter_epub.dart';

class Book {
  final String id, title, author, filePath;
  final String? coverPath;
  final int chapter, chaptersTotal, addedAt;
  final int? lastOpenedAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    this.chapter = 0,
    this.chaptersTotal = 0,
    required this.addedAt,
    this.lastOpenedAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    filePath: json['filePath'] as String,
    coverPath: json['coverPath'] as String?,
    chapter: json['chapter'] as int,
    chaptersTotal: json['chaptersTotal'] as int,
    addedAt: json['addedAt'] as int,
    lastOpenedAt: json['lastOpenedAt'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'filePath': filePath,
    'coverPath': coverPath,
    'chapter': chapter,
    'chaptersTotal': chaptersTotal,
    'addedAt': addedAt,
    'lastOpenedAt': lastOpenedAt,
  };
}

/// One child's shelf, keyed by [childId] like their reading activity (see
/// ActivityService), so renaming a child keeps their books.
class BookLibrary {
  final String childId;
  final Directory? root;
  Future<void> _pending = Future.value();

  BookLibrary(this.childId, {this.root});

  String get _key => 'book_library_$childId';
  String positionKey(Book book) => 'epub_position_${childId}_${book.id}';

  /// Where the paged reader keeps its place: an epub.js CFI, not the
  /// scrolling reader's paragraph index.
  String cfiKey(Book book) => 'epub_cfi_${childId}_${book.id}';

  /// Where chapter [chapter]'s Gemini-written quiz is kept once written.
  String quizKey(Book book, int chapter) => '${_quizPrefix(book)}$chapter';

  String _quizPrefix(Book book) => 'chapter_quiz_${childId}_${book.id}_';

  /// Set once [fillMissingCovers] has looked in [book] for a cover, found or
  /// not, so a book with none isn't opened again on every load.
  String _coverCheckedKey(Book book) =>
      'book_cover_checked_${childId}_${book.id}';

  Future<List<Book>> load() async {
    await _pending;
    return _read();
  }

  Future<List<Book>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(_key) ?? '[]') as List)
        .map((json) => Book.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<void> _write(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    )) {
      throw const FileSystemException('Could not save the book library');
    }
  }

  // Reader callbacks and shelf actions share this instance and cannot clobber
  // each other's read-modify-write updates.
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// The reader draws `<pre>` in a typewriter font, which makes shaped
  /// text (like the Mouse's tail poem in Alice) look like code. This keeps
  /// its lines and indents but uses the book's own font.
  // ponytail: 0.5em per space approximates the monospace shape; exact
  // alignment would need a custom epub_view paragraph builder.
  static String preAsLines(String html) => html.replaceAllMapped(
    RegExp(r'<pre\b[^>]*>([\s\S]*?)</pre>', caseSensitive: false),
    (m) {
      final lines = m[1]!.split('\n');
      while (lines.isNotEmpty && lines.first.trim().isEmpty) {
        lines.removeAt(0);
      }
      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }
      int indent(String line) => line.length - line.trimLeft().length;
      final base = lines
          .where((l) => l.trim().isNotEmpty)
          .map(indent)
          .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
      // Many very short lines means shaped text (a tail, a tree...), which
      // shrinks toward its tip like the printed book.
      // ponytail: line-count/length heuristic; add a per-book flag if a
      // short-lined poem shrinks that shouldn't.
      final shaped =
          lines.length >= 20 &&
          lines.every(
            (l) => l.replaceAll(RegExp(r'<[^>]+>'), '').trim().length <= 16,
          );
      String row(int i) {
        final line = lines[i];
        if (line.trim().isEmpty) {
          return '<div style="margin-left: 0.0em">&#160;</div>';
        }
        final size = shaped ? 1 - 0.5 * i / (lines.length - 1) : 1.0;
        // em margins follow the line's own font size, so undo the shrink
        // to keep each line where the original shape put it.
        final margin = (indent(line) - base!) * 0.5 / size;
        return '<div style="margin-left: ${margin.toStringAsFixed(2)}em'
            '${shaped ? '; font-size: ${size.toStringAsFixed(2)}em' : ''}">'
            '${line.trim()}</div>';
      }

      // One div per line: epub_view turns <br/> into <br></br> (two breaks)
      // and flutter_html drops leading spaces, so indents become margins.
      // The outer div has one child, so epub_view keeps it one paragraph.
      final rows = [for (var i = 0; i < lines.length; i++) row(i)];
      return '<div><div>${rows.join()}</div></div>';
    },
  );

  static Future<EpubBook> readDocument(Uint8List bytes) async {
    if (bytes.isEmpty) throw const FormatException('Empty EPUB');
    return flatten(await EpubDocument.openData(bytes));
  }

  /// Rewrites [book]'s contents in place as one section per XHTML file.
  /// Picture-book detection needs the original contents tree, so it must run
  /// first. Throws when nothing is readable, unless [allowEmpty] (a picture
  /// book can be all images).
  static EpubBook flatten(EpubBook book, {bool allowEmpty = false}) {
    // epub_view 3.2.0 miscalculates offsets for anchored TOC entries. Keep one
    // section per XHTML file, preserving HTML, links and embedded images.
    // ponytail: same-file subheadings stay in the text, not separate TOC rows.
    final sections = <EpubChapter>[];
    final seen = <String>{};
    void collect(List<EpubChapter> chapters) {
      for (final chapter in chapters) {
        final subs = chapter.SubChapters ?? [];
        final file = chapter.ContentFileName;
        if (file != null &&
            (chapter.HtmlContent?.trim().isNotEmpty ?? false) &&
            seen.add(file)) {
          sections.add(
            chapter
              ..Anchor = null
              ..SubChapters = []
              ..HtmlContent = preAsLines(chapter.HtmlContent!),
          );
        }
        collect(subs);
      }
    }

    collect(book.Chapters ?? []);
    if (sections.isEmpty && !allowEmpty) {
      throw const FormatException('No readable EPUB sections');
    }
    book.Chapters = sections;
    return book;
  }

  Future<Book> add({
    required String fileName,
    required Uint8List bytes,
    required String title,
    String author = '',
  }) => _serial(() async {
    if (!fileName.toLowerCase().endsWith('.epub')) {
      throw const FormatException('Please choose an .epub file.');
    }
    if (title.trim().isEmpty) {
      throw const FormatException('Enter a book title.');
    }
    final document = await readDocument(bytes);
    final books = await _read();
    // IDs preserve legacy filename-based resume keys; hashes keep arbitrary
    // picker names and child names out of filesystem paths.
    final name = fileName.split(RegExp(r'[/\\]')).last;
    var id = name;
    for (var n = 2; books.any((b) => b.id == id); n++) {
      id = '${name.substring(0, name.length - 5)}-$n.epub';
    }
    final base = root ?? await getApplicationDocumentsDirectory();
    final child = sha256.convert(utf8.encode(childId));
    final directory = await Directory(
      '${base.path}/books/$child',
    ).create(recursive: true);
    final stem = sha256.convert(utf8.encode(id));
    final file = File('${directory.path}/$stem.epub');
    var cover = File('${directory.path}/$stem.png');
    try {
      await file.writeAsBytes(bytes, flush: true);
      var hasCover = false;
      if (document.CoverImage != null) {
        await cover.writeAsBytes(
          image.encodePng(document.CoverImage!),
          flush: true,
        );
        hasCover = true;
      } else {
        // epubx misses most EPUB 3 covers; find it in the parsed manifest.
        final found = coverFromDocument(document);
        if (found != null) {
          cover = File('${directory.path}/$stem.cover.${found.extension}');
          // Small, and synchronous so no file handle outlives the add.
          cover.writeAsBytesSync(found.bytes, flush: true);
          hasCover = true;
        }
      }
      final book = Book(
        id: id,
        title: title.trim(),
        author: author.trim(),
        filePath: file.path,
        coverPath: hasCover ? cover.path : null,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _write([...books, book]);
      return book;
    } catch (_) {
      if (await file.exists()) await file.delete();
      if (await cover.exists()) await cover.delete();
      rethrow;
    }
  });

  /// The cover of an already parsed book, when epubx didn't find one.
  ///
  /// epubx only follows `<meta name="cover">`, which it drops from EPUB 3
  /// metadata, so this looks for the manifest item EPUB 3 marks
  /// `cover-image`, then for an image called "cover". The bytes are the
  /// image as the book holds it, so nothing is re-encoded.
  static EpubCover? coverFromDocument(EpubBook document) {
    final items = document.Schema?.Package?.Manifest?.Items ?? const [];
    final images = document.Content?.Images ?? const {};
    EpubCover? fromItem(bool Function(EpubManifestItem) test) {
      for (final item in items) {
        if (!(item.MediaType ?? '').startsWith('image/') || !test(item)) {
          continue;
        }
        final bytes = images[item.Href]?.Content;
        if (bytes == null || bytes.isEmpty) continue;
        final href = item.Href!;
        final dot = href.lastIndexOf('.');
        return EpubCover(
          Uint8List.fromList(bytes),
          dot < 0 ? 'img' : href.substring(dot + 1).toLowerCase(),
        );
      }
      return null;
    }

    return fromItem(
          (item) => (item.Properties ?? '').split(' ').contains('cover-image'),
        ) ??
        fromItem(
          (item) => '${item.Id} ${item.Href}'.toLowerCase().contains('cover'),
        );
  }

  /// [readEpubCover] on another isolate. Static on purpose: a closure made
  /// inside an instance method captures `this`, and a library's pending
  /// Future can't be sent between isolates.
  static Future<EpubCover?> _readCoverOffThread(String path) =>
      Isolate.run(() => readEpubCover(path));

  /// Gives books added without a cover one, looking in each book once.
  ///
  /// Shelves filled before EPUB 3 covers were found, like the Alice sample,
  /// have no cover saved. The files are read outside [_serial], off the UI
  /// thread, so a big book doesn't hold up the shelf; only the save waits its
  /// turn. Returns the shelf, updated.
  Future<List<Book>> fillMissingCovers() async {
    final prefs = await SharedPreferences.getInstance();
    final found = <String, String>{};
    for (final book in await load()) {
      if (book.coverPath != null) continue;
      if (prefs.getBool(_coverCheckedKey(book)) ?? false) continue;
      final epub = book.filePath;
      if (!await File(epub).exists()) continue;
      final cover = await _readCoverOffThread(epub);
      await prefs.setBool(_coverCheckedKey(book), true);
      if (cover == null) continue;
      final file = File(
        '${epub.replaceFirst(RegExp(r'\.epub$'), '')}.cover.${cover.extension}',
      );
      await file.writeAsBytes(cover.bytes, flush: true);
      found[book.id] = file.path;
    }
    if (found.isEmpty) return load();
    return _serial(() async {
      // Re-read: the shelf may have changed while the files were read.
      final books = [
        for (final book in await _read())
          found.containsKey(book.id) && book.coverPath == null
              ? Book.fromJson({...book.toJson(), 'coverPath': found[book.id]})
              : book,
      ];
      await _write(books);
      return books;
    });
  }

  Future<void> markOpened(
    Book book, {
    required int chapter,
    required int total,
  }) => _serial(() async {
    if (total < 1) throw ArgumentError.value(total, 'total');
    final books = await _read();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index < 0) return;
    books[index] = Book.fromJson({
      ...books[index].toJson(),
      'chapter': chapter.clamp(1, total),
      'chaptersTotal': total,
      'lastOpenedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _write(books);
  });

  /// Where [lighterCopy] keeps its version of [book], next to the original.
  static String lighterPath(Book book) =>
      book.filePath.replaceFirst(RegExp(r'\.epub$'), '.reader.epub');

  /// A copy of [book] with its pictures re-saved smaller, made once and then
  /// reused, for readers that can't take a file as big as the original. Null
  /// when even the copy is over [maxBytes] (a book that is big for some
  /// other reason than its pictures).
  static Future<String?> lighterCopy(Book book, {required int maxBytes}) async {
    final copy = File(lighterPath(book));
    if (!await copy.exists()) {
      final from = book.filePath;
      // Written beside the final name, so a copy cut short (the app closed
      // mid-way) is never mistaken for a finished one.
      final partial = '${copy.path}.part';
      await Isolate.run(() => shrinkEpubFile(from, partial));
      // Kept even when still too big, so the work isn't repeated each open.
      await File(partial).rename(copy.path);
    }
    return await copy.length() <= maxBytes ? copy.path : null;
  }

  Future<void> remove(Book book) => _serial(() async {
    final books = await _read();
    for (final path in [book.filePath, book.coverPath, lighterPath(book)]) {
      if (path != null && await File(path).exists()) await File(path).delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(positionKey(book));
    await prefs.remove(cfiKey(book));
    await prefs.remove(_coverCheckedKey(book));
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_quizPrefix(book))) await prefs.remove(key);
    }
    // Keep the entry available for a retry if deleting its files fails.
    await _write(books.where((b) => b.id != book.id).toList());
  });
}
