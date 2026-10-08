import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as image;

/// Copies the EPUB at [from] to [to] with its JPEG pictures re-saved at phone
/// size and normal quality, leaving everything else as it was.
///
/// The paged reader hands the whole book to its web view as one JavaScript
/// array, so it can only take books up to a size limit. Illustrated books
/// (Project Gutenberg's "with images" editions, say) are often far over it
/// purely because their pictures were saved at very high quality: Treasure
/// Island is 49 MB, 49.2 of it JPEGs, and about 12 MB after this. 800 px
/// still looks sharp on a phone; at 1200 px (22 MB) the reader's web view
/// load ran the app out of memory.
///
/// Streams one file of the book at a time from disk to disk: holding the
/// whole book in memory alongside the reader got the app killed by Android's
/// low-memory killer on a phone-sized emulator. Pure Dart and slow for a big
/// book, so run it off the UI isolate.
void shrinkEpubFile(
  String from,
  String to, {
  int maxSide = 800,
  int quality = 60,
}) {
  final input = InputFileStream(from);
  final output = ZipFileEncoder()..create(to);
  try {
    for (final file in ZipDecoder().decodeBuffer(input).files) {
      if (!file.isFile) continue;
      var bytes = file.content as List<int>;
      final name = file.name.toLowerCase();
      final isJpeg = name.endsWith('.jpg') || name.endsWith('.jpeg');
      // Small pictures aren't worth decoding.
      if (isJpeg && bytes.length > 64 * 1024) {
        bytes = _shrinkJpeg(bytes, maxSide, quality) ?? bytes;
      }
      final copy = ArchiveFile(file.name, bytes.length, bytes)
        // The EPUB spec wants `mimetype` stored, not deflated, and JPEGs
        // don't deflate anyway.
        ..compress = name != 'mimetype' && !isJpeg;
      output.addArchiveFile(copy);
      file.clear();
    }
  } finally {
    output.closeSync();
    input.closeSync();
  }
}

/// The picture at most [maxSide] on its longer side, or null when it can't
/// be read or re-saving it wouldn't make it smaller.
List<int>? _shrinkJpeg(List<int> bytes, int maxSide, int quality) {
  final picture = image.decodeJpg(bytes);
  if (picture == null) return null;
  final longer = picture.width > picture.height
      ? picture.width
      : picture.height;
  final sized = longer <= maxSide
      ? picture
      : image.copyResize(
          picture,
          width: picture.width >= picture.height ? maxSide : null,
          height: picture.height > picture.width ? maxSide : null,
          interpolation: image.Interpolation.average,
        );
  final smaller = image.encodeJpg(sized, quality: quality);
  return smaller.length < bytes.length ? smaller : null;
}
