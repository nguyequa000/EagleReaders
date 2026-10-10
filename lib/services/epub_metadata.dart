import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// The title and author an EPUB gives itself. Either may be empty.
class EpubInfo {
  final String title, author;

  const EpubInfo({this.title = '', this.author = ''});
}

/// [EpubInfo] for the EPUB in [bytes], reading only its package file. Null
/// when it isn't a readable EPUB.
EpubInfo? readEpubInfo(Uint8List bytes) {
  try {
    return _infoOf(ZipDecoder().decodeBytes(bytes));
  } catch (_) {
    return null;
  }
}

/// [readEpubInfo] for the EPUB at [path], without reading the whole file.
EpubInfo? readEpubInfoFile(String path) {
  final input = InputFileStream(path);
  try {
    return _infoOf(ZipDecoder().decodeBuffer(input));
  } catch (_) {
    return null;
  } finally {
    input.closeSync();
  }
}

/// [readEpubInfoFile] on another isolate, so a big book doesn't hold up the
/// screen.
Future<EpubInfo?> readEpubInfoOffThread(String path) =>
    Isolate.run(() => readEpubInfoFile(path));

EpubInfo? _infoOf(Archive archive) {
  String? text(String name) {
    for (final file in archive.files) {
      if (file.name == name) {
        return utf8.decode(file.content as List<int>, allowMalformed: true);
      }
    }
    return null;
  }

  final container = text('META-INF/container.xml');
  if (container == null) return null;
  final opfPath = RegExp(
    r'''full-path\s*=\s*["']([^"']+)["']''',
  ).firstMatch(container)?.group(1);
  final opf = opfPath == null ? null : text(opfPath);
  if (opf == null) return null;
  return epubInfoFromOpf(opf);
}

/// The first `<dc:title>` and `<dc:creator>` in an OPF package document.
EpubInfo epubInfoFromOpf(String opf) {
  final metadata =
      RegExp(
        r'<(?:\w+:)?metadata\b[\s\S]*?</(?:\w+:)?metadata>',
        caseSensitive: false,
      ).firstMatch(opf)?.group(0) ??
      opf;
  String first(String element) => _plain(
    RegExp(
      '<(?:\\w+:)?$element\\b[^>]*>([\\s\\S]*?)</(?:\\w+:)?$element>',
      caseSensitive: false,
    ).firstMatch(metadata)?.group(1),
  );
  return EpubInfo(title: first('title'), author: first('creator'));
}

/// [xml] as plain text: tags dropped, entities decoded, spaces collapsed.
String _plain(String? xml) => (xml ?? '')
    .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
      (m) => switch (m[1]!) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        final code when code.startsWith('#x') => String.fromCharCode(
          int.parse(code.substring(2), radix: 16),
        ),
        final code => String.fromCharCode(int.parse(code.substring(1))),
      },
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A readable title made from a file name, for an EPUB that doesn't name
/// itself: `alice_in_wonderland.epub` becomes "Alice In Wonderland".
String titleFromFileName(String fileName) {
  final name = fileName
      .split(RegExp(r'[/\\]'))
      .last
      .replaceFirst(RegExp(r'\.epub$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_.\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.isEmpty) return fileName;
  return name
      .split(' ')
      .map(
        (word) => word == word.toLowerCase()
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : word,
      )
      .join(' ');
}
