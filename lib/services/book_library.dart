import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:epub_view/epub_view.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class BookLibrary {
  final String childName;
  final Directory? root;
  Future<void> _pending = Future.value();

  BookLibrary(this.childName, {this.root});

  String get _key => 'book_library_$childName';
  String positionKey(Book book) => 'epub_position_${childName}_${book.id}';

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
    final book = await EpubDocument.openData(bytes);
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
    if (sections.isEmpty) {
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
    final child = sha256.convert(utf8.encode(childName));
    final directory = await Directory(
      '${base.path}/books/$child',
    ).create(recursive: true);
    final stem = sha256.convert(utf8.encode(id));
    final file = File('${directory.path}/$stem.epub');
    final cover = File('${directory.path}/$stem.png');
    try {
      await file.writeAsBytes(bytes, flush: true);
      if (document.CoverImage != null) {
        await cover.writeAsBytes(
          image.encodePng(document.CoverImage!),
          flush: true,
        );
      }
      final book = Book(
        id: id,
        title: title.trim(),
        author: author.trim(),
        filePath: file.path,
        coverPath: document.CoverImage == null ? null : cover.path,
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

  Future<void> remove(Book book) => _serial(() async {
    final books = await _read();
    for (final path in [book.filePath, book.coverPath]) {
      if (path != null && await File(path).exists()) await File(path).delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(positionKey(book));
    // Keep the entry available for a retry if deleting its files fails.
    await _write(books.where((b) => b.id != book.id).toList());
  });
}
