import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// A book's cover picture, as stored in the EPUB.
class EpubCover {
  /// The image file exactly as the EPUB holds it (not re-encoded).
  final Uint8List bytes;

  /// Its extension, e.g. `jpg`, for naming the copy kept beside the book.
  final String extension;

  const EpubCover(this.bytes, this.extension);
}

/// Finds the cover in the EPUB at [path], reading only the package file and
/// the cover itself rather than parsing the whole book. Null when the book
/// has none.
///
/// Exists because epub_view's parser (epubx) misses most EPUB 3 covers: it
/// only follows `<meta name="cover">`, and drops that element when it reads
/// EPUB 3 metadata. Tries, in order:
/// 1. the manifest item marked `properties="cover-image"` (EPUB 3),
/// 2. the item named by `<meta name="cover" content="…">` (EPUB 2),
/// 3. an image whose id or file name says "cover".
EpubCover? readEpubCover(String path) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    ArchiveFile? find(String name) {
      for (final file in archive.files) {
        if (file.name == name) return file;
      }
      return null;
    }

    final container = find('META-INF/container.xml');
    if (container == null) return null;
    final opfPath = RegExp(
      r'full-path\s*=\s*"([^"]+)"',
    ).firstMatch(_text(container))?.group(1);
    if (opfPath == null) return null;
    final opf = find(opfPath);
    if (opf == null) return null;

    final href = coverHref(_text(opf));
    if (href == null) return null;
    final base = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';
    final image = find(_resolve(base, Uri.decodeFull(href)));
    if (image == null) return null;
    final bytes = Uint8List.fromList(image.content as List<int>);
    if (bytes.isEmpty) return null;
    final dot = href.lastIndexOf('.');
    final extension = dot < 0 ? 'img' : href.substring(dot + 1).toLowerCase();
    return EpubCover(bytes, extension);
  } catch (_) {
    // A damaged or unusual file just means no cover; the book still reads.
    return null;
  } finally {
    input.closeSync();
  }
}

/// The cover image's `href` from an OPF package document, or null.
String? coverHref(String opf) {
  final items = [
    for (final tag in RegExp(r'<item\b[^>]*>').allMatches(opf))
      _attributes(tag.group(0)!),
  ];
  bool isImage(Map<String, String> item) =>
      (item['media-type'] ?? '').startsWith('image/');

  for (final item in items) {
    final properties = (item['properties'] ?? '').split(RegExp(r'\s+'));
    if (properties.contains('cover-image') && isImage(item)) {
      return item['href'];
    }
  }

  for (final tag in RegExp(r'<meta\b[^>]*>').allMatches(opf)) {
    final meta = _attributes(tag.group(0)!);
    if (meta['name']?.toLowerCase() != 'cover') continue;
    final id = meta['content']?.toLowerCase();
    for (final item in items) {
      if (item['id']?.toLowerCase() == id && isImage(item)) return item['href'];
    }
  }

  for (final item in items) {
    final name = '${item['id']} ${item['href']}'.toLowerCase();
    if (isImage(item) && name.contains('cover')) return item['href'];
  }
  return null;
}

Map<String, String> _attributes(String tag) => {
  for (final m in RegExp(
    r'''([\w:-]+)\s*=\s*("([^"]*)"|'([^']*)')''',
  ).allMatches(tag))
    m.group(1)!.toLowerCase(): m.group(3) ?? m.group(4) ?? '',
};

String _text(ArchiveFile file) =>
    utf8.decode(file.content as List<int>, allowMalformed: true);

/// [href] relative to the package file's folder, with `..` and `.` resolved.
String _resolve(String base, String href) {
  final parts = <String>[];
  for (final part in '$base$href'.split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}
