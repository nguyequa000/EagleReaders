import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A book's cover from its file on this device, or [fallback] without one.
///
/// Reads the file once, synchronously, and keeps the bytes, rather than using
/// `Image.file`. That one holds the file open while it loads, and on Windows
/// an open file can't be deleted, so removing the book (or a test cleaning up
/// its temporary shelf) failed while a cover was on screen. Covers are small
/// and few, so the read and the cache cost little.
class BookCover extends StatelessWidget {
  /// The cover image file (`Book.coverPath`), or null.
  final String? path;
  final Widget fallback;
  final BoxFit fit;

  const BookCover({
    super.key,
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  static final Map<String, Uint8List?> _cache = {};

  static Uint8List? _bytes(String path) => _cache.putIfAbsent(path, () {
    try {
      return File(path).readAsBytesSync();
    } catch (_) {
      // Missing or unreadable: the fallback stands in.
      return null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final file = path;
    final bytes = file == null ? null : _bytes(file);
    if (bytes == null || bytes.isEmpty) return fallback;
    return Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
