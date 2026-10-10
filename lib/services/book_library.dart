import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:epub_view/epub_view.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/picture_book_view.dart' show readPictureBook;
import 'epub_cover.dart';
import 'lighter_epub.dart';

class Book {
  final String id, title, author, filePath;
  final String? coverPath;
  final int chapter, chaptersTotal, addedAt;
  final int? lastOpenedAt;

  /// The children (by id) this book is on the shelf for.
  final List<String> readers;

  /// Whether the reader shows it a picture at a time (comics etc.; see
  /// readPictureBook). Null for books added before this was recorded.
  final bool? pictureBook;

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
    this.readers = const [],
    this.pictureBook,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    filePath: json['filePath'] as String,
    coverPath: json['coverPath'] as String?,
    chapter: json['chapter'] as int? ?? 0,
    chaptersTotal: json['chaptersTotal'] as int? ?? 0,
    addedAt: json['addedAt'] as int,
    lastOpenedAt: json['lastOpenedAt'] as int?,
    readers: [...?(json['readers'] as List?)?.cast<String>()],
    pictureBook: json['pictureBook'] as bool?,
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
    'readers': readers,
    'pictureBook': pictureBook,
  };

  Book _with(Map<String, dynamic> changes) =>
      Book.fromJson({...toJson(), ...changes});
}

/// The family's books on this device: imported once in Manage Shelf, then
/// given to the children who should read them ([Book.readers]).
///
/// How far each child has got lives apart from the book, per child (see
/// [BookLibrary]), so one book can be on several shelves.
class BookShelf {
  final Directory? root;

  BookShelf({this.root});

  static const _key = 'book_shelf';

  /// Where each child's shelf lived before there was one family shelf. Moved
  /// into it on first read (see [_migrate]).
  static const _legacyPrefix = 'book_library_';

  static String _progressKey(String childId) => 'book_progress_$childId';

  // Keys a child's reading of a book is saved under; BookLibrary's key
  // getters use the same ones.
  static String _positionKey(String childId, String id) =>
      'epub_position_${childId}_$id';
  static String _cfiKey(String childId, String id) => 'epub_cfi_${childId}_$id';
  static String _quizPrefix(String childId, String id) =>
      'chapter_quiz_${childId}_${id}_';

  /// Set once [fillMissingCovers] has looked in a book for a cover, found or
  /// not, so a book with none isn't opened again on every load.
  static String _coverCheckedKey(String id) => 'book_cover_checked_$id';

  // Reader callbacks and shelf actions share an instance (a child's
  // BookLibrary goes through its own shelf) and cannot clobber each other's
  // read-modify-write updates.
  Future<void> _pending = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Every book, oldest first.
  Future<List<Book>> load() => _serial(_read);

  Future<List<Book>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final books = _decode(prefs.getString(_key));
    final legacy = [
      for (final key in prefs.getKeys())
        if (key.startsWith(_legacyPrefix)) key,
    ];
    return legacy.isEmpty ? books : _migrate(prefs, books, legacy);
  }

  static List<Book> _decode(String? json) => (jsonDecode(json ?? '[]') as List)
      .map((json) => Book.fromJson(Map<String, dynamic>.from(json as Map)))
      .toList();

  Future<void> _write(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    )) {
      throw const FileSystemException('Could not save the book library');
    }
  }

  static Map<String, Map<String, dynamic>> _progress(
    SharedPreferences prefs,
    String childId,
  ) => {
    for (final MapEntry(:key, :value)
        in (jsonDecode(prefs.getString(_progressKey(childId)) ?? '{}') as Map)
            .entries)
      key as String: Map<String, dynamic>.from(value as Map),
  };

  static Future<void> _writeProgress(
    SharedPreferences prefs,
    String childId,
    Map<String, Map<String, dynamic>> progress,
  ) async {
    if (!await prefs.setString(_progressKey(childId), jsonEncode(progress))) {
      throw const FileSystemException('Could not save reading progress');
    }
  }

  /// Moves each child's old shelf into this one, keeping their place in every
  /// book. Safe to repeat if the app stops part way: a book already moved is
  /// recognised by its file.
  Future<List<Book>> _migrate(
    SharedPreferences prefs,
    List<Book> books,
    List<String> legacyKeys,
  ) async {
    final duplicates = <Book>[];
    for (final key in legacyKeys) {
      final childId = key.substring(_legacyPrefix.length);
      final progress = _progress(prefs, childId);
      final renames = <String, String>{};
      for (final old in _decode(prefs.getString(key))) {
        var index = books.indexWhere((b) => b.filePath == old.filePath);
        if (index < 0) {
          // The same book given to two children was imported twice.
          final same = books.indexWhere((b) => b.id == old.id);
          if (same >= 0 &&
              await _sameFile(books[same].filePath, old.filePath)) {
            index = same;
            duplicates.add(old);
          }
        }
        final String id;
        if (index >= 0) {
          id = books[index].id;
          books[index] = books[index]._with({
            'readers': {...books[index].readers, childId}.toList(),
          });
        } else {
          id = _freeId(books, old.id);
          books.add(
            old._with({
              'id': id,
              'chapter': 0,
              'chaptersTotal': 0,
              'lastOpenedAt': null,
              'readers': [childId],
            }),
          );
        }
        if (id != old.id) renames[old.id] = id;
        if (old.chapter > 0 || old.lastOpenedAt != null) {
          progress[id] = {
            'chapter': old.chapter,
            'chaptersTotal': old.chaptersTotal,
            'lastOpenedAt': old.lastOpenedAt,
          };
        }
      }
      await _write(books);
      await _writeProgress(prefs, childId, progress);
      for (final MapEntry(key: from, value: to) in renames.entries) {
        await _renameKeys(prefs, childId, from, to);
      }
      // Cover checks are per book now, not per child.
      for (final old in prefs.getKeys().toList()) {
        if (old.startsWith('book_cover_checked_${childId}_')) {
          await prefs.remove(old);
        }
      }
      await prefs.remove(key);
    }
    // Only once nothing points at them any more.
    for (final book in duplicates) {
      await _deleteFiles(book);
    }
    return books;
  }

  static Future<bool> _sameFile(String a, String b) async {
    final first = File(a), second = File(b);
    if (!await first.exists() || !await second.exists()) return false;
    if (await first.length() != await second.length()) return false;
    // Streamed, so a big book is never read into memory whole.
    final hashes = await Future.wait([
      sha256.bind(first.openRead()).first,
      sha256.bind(second.openRead()).first,
    ]);
    return hashes[0] == hashes[1];
  }

  static Future<void> _renameKeys(
    SharedPreferences prefs,
    String childId,
    String from,
    String to,
  ) async {
    Future<void> move(String old, String now) async {
      final value = prefs.get(old);
      if (value == null) return;
      switch (value) {
        case int value:
          await prefs.setInt(now, value);
        case String value:
          await prefs.setString(now, value);
        case bool value:
          await prefs.setBool(now, value);
        case double value:
          await prefs.setDouble(now, value);
        case List value:
          await prefs.setStringList(now, value.cast<String>());
      }
      await prefs.remove(old);
    }

    await move(_positionKey(childId, from), _positionKey(childId, to));
    await move(_cfiKey(childId, from), _cfiKey(childId, to));
    final quiz = _quizPrefix(childId, from);
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(quiz)) {
        await move(
          key,
          '${_quizPrefix(childId, to)}${key.substring(quiz.length)}',
        );
      }
    }
  }

  /// [id], or the first `name-2.epub`, `name-3.epub`... not on [books].
  static String _freeId(List<Book> books, String id) {
    final stem = id.toLowerCase().endsWith('.epub')
        ? id.substring(0, id.length - 5)
        : id;
    var free = id;
    for (var n = 2; books.any((b) => b.id == free); n++) {
      free = '$stem-$n.epub';
    }
    return free;
  }

  Future<Book> add({
    required String fileName,
    required Uint8List bytes,
    required String title,
    String author = '',
    Iterable<String> readers = const [],
  }) => _serial(() async {
    if (!fileName.toLowerCase().endsWith('.epub')) {
      throw const FormatException('Please choose an .epub file.');
    }
    if (title.trim().isEmpty) {
      throw const FormatException('Enter a book title.');
    }
    if (bytes.isEmpty) throw const FormatException('Empty EPUB');
    final raw = await EpubDocument.openData(bytes);
    // Before flatten(), which rewrites the contents tree in place.
    final pictures = readPictureBook(raw) != null;
    final document = BookLibrary.flatten(raw, allowEmpty: pictures);
    final books = await _read();
    // IDs preserve legacy filename-based resume keys; hashes keep arbitrary
    // picker names out of filesystem paths.
    final id = _freeId(books, fileName.split(RegExp(r'[/\\]')).last);
    final base = root ?? await getApplicationDocumentsDirectory();
    final directory = await Directory(
      '${base.path}/books/shelf',
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
        final found = BookLibrary.coverFromDocument(document);
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
        readers: readers.toSet().toList(),
        pictureBook: pictures,
      );
      await _write([...books, book]);
      return book;
    } catch (_) {
      if (await file.exists()) await file.delete();
      if (await cover.exists()) await cover.delete();
      rethrow;
    }
  });

  Future<Book> _update(String id, Book Function(Book) change) =>
      _serial(() async {
        final books = await _read();
        final index = books.indexWhere((b) => b.id == id);
        if (index < 0) throw StateError('No book $id on the shelf');
        books[index] = change(books[index]);
        await _write(books);
        return books[index];
      });

  /// Changes the title and author shown on every child's shelf.
  Future<Book> rename(String id, {required String title, String author = ''}) {
    if (title.trim().isEmpty) {
      throw const FormatException('Enter a book title.');
    }
    return _update(
      id,
      (book) => book._with({'title': title.trim(), 'author': author.trim()}),
    );
  }

  /// Puts the book on exactly these children's shelves. A child it's taken
  /// from keeps their place, in case it's given back.
  Future<Book> setReaders(String id, Iterable<String> readers) =>
      _update(id, (book) => book._with({'readers': readers.toSet().toList()}));

  /// Whether [book] is a picture book, which the reader never needs a
  /// lighter copy of. Worked out once, off the UI thread, for a book added
  /// before that was recorded.
  Future<bool> isPictureBook(Book book) async {
    if (book.pictureBook case final known?) return known;
    final pictures = await _isPictureBookOffThread(book.filePath);
    await _update(book.id, (b) => b._with({'pictureBook': pictures}));
    return pictures;
  }

  /// Static for the same reason as [_readCoverOffThread].
  static Future<bool> _isPictureBookOffThread(String path) => Isolate.run(
    () async =>
        readPictureBook(
          await EpubDocument.openData(await File(path).readAsBytes()),
        ) !=
        null,
  );

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
      if (prefs.getBool(_coverCheckedKey(book.id)) ?? false) continue;
      final epub = book.filePath;
      if (!await File(epub).exists()) continue;
      final cover = await _readCoverOffThread(epub);
      await prefs.setBool(_coverCheckedKey(book.id), true);
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
              ? book._with({'coverPath': found[book.id]})
              : book,
      ];
      await _write(books);
      return books;
    });
  }

  /// [readEpubCover] on another isolate. Static on purpose: a closure made
  /// inside an instance method captures `this`, and a shelf's pending
  /// Future can't be sent between isolates.
  static Future<EpubCover?> _readCoverOffThread(String path) =>
      Isolate.run(() => readEpubCover(path));

  /// Takes the book off every child's shelf and deletes it, with everything
  /// saved about reading it.
  Future<void> remove(Book book) => _serial(() => _removeNow(book));

  Future<void> _removeNow(Book book) async {
    final books = await _read();
    final stored = books.where((b) => b.id == book.id).firstOrNull ?? book;
    await _deleteFiles(stored);
    final prefs = await SharedPreferences.getInstance();
    final children = {
      ...stored.readers,
      for (final key in prefs.getKeys())
        if (key.startsWith('book_progress_'))
          key.substring('book_progress_'.length),
    };
    for (final child in children) {
      await _forget(prefs, child, book.id);
    }
    await prefs.remove(_coverCheckedKey(book.id));
    // Keep the entry available for a retry if deleting its files fails.
    await _write(books.where((b) => b.id != book.id).toList());
  }

  static Future<void> _deleteFiles(Book book) async {
    for (final path in [
      book.filePath,
      book.coverPath,
      BookLibrary.lighterPath(book),
    ]) {
      if (path != null && await File(path).exists()) await File(path).delete();
    }
  }

  /// Clears [childId]'s place, progress and quizzes in book [id].
  static Future<void> _forget(
    SharedPreferences prefs,
    String childId,
    String id,
  ) async {
    await prefs.remove(_positionKey(childId, id));
    await prefs.remove(_cfiKey(childId, id));
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_quizPrefix(childId, id))) await prefs.remove(key);
    }
    final progress = _progress(prefs, childId);
    if (progress.remove(id) != null) {
      await _writeProgress(prefs, childId, progress);
    }
  }
}

/// One child's shelf: the family [BookShelf]'s books given to [childId], with
/// how far this child has got in each. Keyed by [childId] like their reading
/// activity (see ActivityService), so renaming a child keeps their books.
class BookLibrary {
  final String childId;
  final Directory? root;
  late final BookShelf shelf = BookShelf(root: root);

  BookLibrary(this.childId, {this.root});

  String positionKey(Book book) => BookShelf._positionKey(childId, book.id);

  /// Where the paged reader keeps its place: an epub.js CFI, not the
  /// scrolling reader's paragraph index.
  String cfiKey(Book book) => BookShelf._cfiKey(childId, book.id);

  /// Where chapter [chapter]'s Gemini-written quiz is kept once written.
  String quizKey(Book book, int chapter) =>
      '${BookShelf._quizPrefix(childId, book.id)}$chapter';

  /// This child's books, oldest first, each with their progress in it.
  Future<List<Book>> load() => shelf._serial(_read);

  Future<List<Book>> _read() async {
    final books = await shelf._read();
    final prefs = await SharedPreferences.getInstance();
    final progress = BookShelf._progress(prefs, childId);
    return [
      for (final book in books)
        if (book.readers.contains(childId))
          book._with({
            'chapter': 0,
            'chaptersTotal': 0,
            'lastOpenedAt': null,
            ...?progress[book.id],
          }),
    ];
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

  /// Adds a book to the family shelf, for this child only.
  Future<Book> add({
    required String fileName,
    required Uint8List bytes,
    required String title,
    String author = '',
  }) async {
    final book = await shelf.add(
      fileName: fileName,
      bytes: bytes,
      title: title,
      author: author,
      readers: [childId],
    );
    return (await load()).firstWhere((b) => b.id == book.id);
  }

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

  /// [BookShelf.fillMissingCovers], then this child's books.
  Future<List<Book>> fillMissingCovers() async {
    await shelf.fillMissingCovers();
    return load();
  }

  Future<void> markOpened(
    Book book, {
    required int chapter,
    required int total,
  }) => shelf._serial(() async {
    if (total < 1) throw ArgumentError.value(total, 'total');
    final prefs = await SharedPreferences.getInstance();
    final progress = BookShelf._progress(prefs, childId);
    progress[book.id] = {
      'chapter': chapter.clamp(1, total),
      'chaptersTotal': total,
      'lastOpenedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await BookShelf._writeProgress(prefs, childId, progress);
  });

  /// Where [lighterCopy] keeps its version of [book], next to the original.
  static String lighterPath(Book book) =>
      book.filePath.replaceFirst(RegExp(r'\.epub$'), '.reader.epub');

  /// Copies being made right now, by path, so Manage Shelf getting a book
  /// ready and the reader opening it can't both write the same file.
  static final _making = <String, Future<void>>{};

  /// A copy of [book] with its pictures re-saved smaller, made once and then
  /// reused, for readers that can't take a file as big as the original. Null
  /// when even the copy is over [maxBytes] (a book that is big for some
  /// other reason than its pictures).
  static Future<String?> lighterCopy(Book book, {required int maxBytes}) async {
    final copy = File(lighterPath(book));
    if (!await copy.exists()) {
      // A block body: returning the removed Future would make it wait on
      // itself.
      await (_making[copy.path] ??= _makeLighterCopy(book.filePath, copy.path)
          .whenComplete(() {
            _making.remove(copy.path);
          }));
    }
    return await copy.length() <= maxBytes ? copy.path : null;
  }

  static Future<void> _makeLighterCopy(String from, String to) async {
    // Written beside the final name, so a copy cut short (the app closed
    // mid-way) is never mistaken for a finished one.
    final partial = '$to.part';
    await Isolate.run(() => shrinkEpubFile(from, partial));
    // Kept even when still too big, so the work isn't repeated each open.
    await File(partial).rename(to);
  }

  /// Takes the book off this child's shelf, forgetting their place in it.
  /// A book no other child has is deleted.
  Future<void> remove(Book book) => shelf._serial(() async {
    final books = await shelf._read();
    final stored = books.where((b) => b.id == book.id).firstOrNull;
    final others = [...?stored?.readers]..remove(childId);
    if (others.isEmpty) return shelf._removeNow(book);
    final prefs = await SharedPreferences.getInstance();
    await BookShelf._forget(prefs, childId, book.id);
    await shelf._write([
      for (final b in books) b.id == book.id ? b._with({'readers': others}) : b,
    ]);
  });
}
