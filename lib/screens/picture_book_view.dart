import 'dart:typed_data';

import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter/material.dart';

import 'chapter_quiz.dart';

/// Pages that are "just a picture" may still carry a stray page number or
/// caption; anything longer than this is real text.
const _maxPictureCaptionChars = 40;

final _imgSrc = RegExp(r'''<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']''');
final _svgImageHref = RegExp(
  r'''<image\b[^>]*?\b(?:xlink:)?href\s*=\s*["']([^"']+)["']''',
);
final _tags = RegExp(r'<[^>]*>');
final _headOrStyle = RegExp(
  r'<(head|style|script)\b.*?</\1>',
  dotAll: true,
  caseSensitive: false,
);

/// A table-of-contents entry of a [PictureBook], resolved to a page index.
class PictureBookChapter {
  const PictureBookChapter(this.title, this.page, {this.depth = 0});

  final String title;
  final int page;

  /// Nesting level in the book's contents (0 = top level).
  final int depth;
}

/// A picture book's page images in reading order, plus its contents.
class PictureBook {
  const PictureBook(this.pages, this.chapters);

  final List<Uint8List> pages;

  /// In contents order; empty when the book has no usable contents.
  final List<PictureBookChapter> chapters;

  /// The chapter [page] belongs to: the one starting latest at or before it.
  PictureBookChapter? chapterAt(int page) {
    PictureBookChapter? found;
    for (final chapter in chapters) {
      if (chapter.page <= page && chapter.page >= (found?.page ?? 0)) {
        found = chapter;
      }
    }
    return found;
  }
}

/// [book] as a picture book (comic, picture book, fixed-layout scan), or null
/// when it is an ordinary text book.
///
/// A picture book is one where nearly every spine page is a single image with
/// next to no text. Such books read badly as one long scroll — a fling skips
/// several pages — so the reader shows them one page at a time instead.
/// Pages without an image (e.g. a lone copyright page) are skipped.
///
/// Reads [EpubBook.Chapters] for the contents, so call this before anything
/// flattens or rewrites that tree.
PictureBook? readPictureBook(EpubBook book) {
  final package = book.Schema?.Package;
  final spine = package?.Spine?.Items ?? const [];
  final manifest = {
    for (final item in package?.Manifest?.Items ?? const <EpubManifestItem>[])
      if (item.Id != null && item.Href != null) item.Id!: item.Href!,
  };
  final html = book.Content?.Html ?? const {};
  final images = book.Content?.Images ?? const {};
  final imagesByPath = {
    for (final entry in images.entries) _normalize(entry.key): entry.value,
  };

  var textPages = 0;
  final pages = <Uint8List>[];
  // Spine file -> index of the first page at or after it, so a contents entry
  // pointing at a skipped (non-picture) page lands on the next picture.
  final pageAt = <String, int>{};
  for (final ref in spine) {
    final href = manifest[ref.IdRef];
    final content = href == null ? null : html[href]?.Content;
    if (href == null || content == null) continue;
    pageAt.putIfAbsent(_normalize(href), () => pages.length);

    final body = content.replaceAll(_headOrStyle, ' ');
    final text = body.replaceAll(_tags, ' ').replaceAll(RegExp(r'\s+'), ' ');
    if (text.trim().length > _maxPictureCaptionChars) {
      textPages++;
      continue;
    }

    final src = (_imgSrc.firstMatch(body) ?? _svgImageHref.firstMatch(body))
        ?.group(1);
    if (src == null) continue;
    final bytes = imagesByPath[_resolve(href, src)]?.Content;
    if (bytes != null && bytes.isNotEmpty) {
      pages.add(Uint8List.fromList(bytes));
    }
  }

  // Mostly-picture books only: an illustrated novel stays in the text reader.
  if (pages.length < 2 || textPages * 10 > pages.length) return null;

  final chapters = <PictureBookChapter>[];
  void collect(List<EpubChapter> entries, int depth) {
    for (final entry in entries) {
      final title = entry.Title?.trim() ?? '';
      final file = entry.ContentFileName;
      final page = file == null
          ? null
          : pageAt[_normalize(file.split('#').first)];
      if (title.isNotEmpty && page != null) {
        chapters.add(
          PictureBookChapter(
            title,
            page.clamp(0, pages.length - 1),
            depth: depth,
          ),
        );
      }
      collect(entry.SubChapters ?? const [], depth + 1);
    }
  }

  collect(book.Chapters ?? const [], 0);
  return PictureBook(pages, chapters);
}

String _normalize(String path) {
  var decoded = path;
  try {
    decoded = Uri.decodeFull(path);
  } on ArgumentError {
    // A stray '%' that is not an escape; use the path as written.
  }
  return decoded.replaceAll('\\', '/').replaceFirst(RegExp('^/'), '');
}

/// Resolves an image reference [src] found in the page at [pageHref] to the
/// key `Content.Images` uses (a path relative to the package root).
String _resolve(String pageHref, String src) {
  final segments = _normalize(pageHref).split('/')..removeLast();
  for (final part in _normalize(src.split('#').first).split('/')) {
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// One-page-at-a-time viewer for [readPictureBook]: swipe or use the buttons
/// to turn exactly one page, or jump to a chapter from Contents; double-tap to
/// zoom into a panel, then pinch and drag to look around, and double-tap again
/// to zoom back out.
///
/// Zooming is entered by double-tap rather than an always-on pinch because a
/// zoom handler wrapping the page competes with the page swipe for every drag:
/// a quick flick passes both gesture thresholds in one move and the zoom
/// handler wins, so the page never turned.
class PictureBookView extends StatefulWidget {
  const PictureBookView({
    super.key,
    required this.book,
    required this.onPageChanged,
    required this.onFinish,
    this.onChapterEnd,
    this.initialPage = 0,
    this.enabled = true,
    this.background = Colors.black,
    this.accent = Colors.green,
  });

  final PictureBook book;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFinish;

  /// Called when the child turns the page out of a chapter, for its quiz.
  final ValueChanged<FinishedChapter>? onChapterEnd;

  /// False while the parent is busy (e.g. finishing the book).
  final bool enabled;
  final Color background;
  final Color accent;

  @override
  State<PictureBookView> createState() => _PictureBookViewState();
}

class _PictureBookViewState extends State<PictureBookView> {
  late final PageController _pageController;
  late int _page;
  final _zoom = TransformationController();
  bool _zoomed = false;
  Offset _doubleTapAt = Offset.zero;

  late final _quiz = ChapterQuizTrigger([
    for (final c in widget.book.chapters) (title: c.title, depth: c.depth),
  ]);

  /// True while jumping from Contents, which shouldn't count as finishing a
  /// chapter.
  bool _jumping = false;

  static const _doubleTapScale = 2.5;

  int get _count => widget.book.pages.length;
  bool get _isLast => _page == _count - 1;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _count - 1);
    _pageController = PageController(initialPage: _page);
    _quiz.moveTo(_contentsEntryAt(_page), pageTurn: false);
  }

  int? _contentsEntryAt(int page) {
    final chapter = widget.book.chapterAt(page);
    return chapter == null ? null : widget.book.chapters.indexOf(chapter);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= _count) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showContents() {
    final chapters = widget.book.chapters;
    final current = widget.book.chapterAt(_page);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          itemCount: chapters.length,
          itemBuilder: (_, index) {
            final chapter = chapters[index];
            return ListTile(
              contentPadding: EdgeInsetsDirectional.only(
                start: 16 + 16.0 * chapter.depth,
                end: 16,
              ),
              title: Text(chapter.title),
              trailing: Text('p. ${chapter.page + 1}'),
              selected: identical(chapter, current),
              onTap: () {
                Navigator.pop(sheetContext);
                // Jump rather than animate: a chapter can be 100 pages away.
                // The page-changed callback runs synchronously inside it.
                _jumping = true;
                _pageController.jumpToPage(chapter.page);
                _jumping = false;
              },
            );
          },
        ),
      ),
    );
  }

  void _onPageChanged(int page) {
    // A new page always starts un-zoomed.
    _zoom.value = Matrix4.identity();
    setState(() {
      _page = page;
      _zoomed = false;
    });
    widget.onPageChanged(page);
    final finished = _quiz.moveTo(_contentsEntryAt(page), pageTurn: !_jumping);
    if (finished != null) widget.onChapterEnd?.call(finished);
  }

  void _toggleZoom() {
    if (_zoomed) return _resetZoom();
    // Scale about the tapped point so that spot stays under the finger.
    final p = _doubleTapAt;
    const s = _doubleTapScale;
    _zoom.value = Matrix4.diagonal3Values(s, s, 1)
      ..setTranslationRaw(-p.dx * (s - 1), -p.dy * (s - 1), 0);
    setState(() => _zoomed = true);
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
    setState(() => _zoomed = false);
  }

  /// Pinching all the way back out leaves zoom mode, so swiping works again.
  void _onZoomEnd(ScaleEndDetails _) {
    if (_zoom.value.getMaxScaleOnAxis() <= 1.01) _resetZoom();
  }

  @override
  Widget build(BuildContext context) {
    final pagesLeft = _count - _page - 1;
    final pagesLeftLabel = switch (pagesLeft) {
      <= 0 => 'Last page!',
      1 => '1 page left',
      _ => '$pagesLeft pages left',
    };
    final chapter = widget.book.chapterAt(_page);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Page ${_page + 1} of $_count',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_page + 1) / _count,
                  minHeight: 10,
                  color: widget.accent,
                  backgroundColor: widget.accent.withValues(alpha: 0.15),
                  semanticsLabel: 'Reading progress',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chapter == null
                    ? pagesLeftLabel
                    : '${chapter.title} · $pagesLeftLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: widget.background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Decode at about screen resolution (with headroom for
                // zooming) rather than the full scan size, to keep memory
                // down on large comics.
                final decodeWidth =
                    (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context) *
                            1.5)
                        .round();
                return PageView.builder(
                  controller: _pageController,
                  itemCount: _count,
                  // While zoomed, a drag pans the panel instead of turning
                  // the page.
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final page = GestureDetector(
                      // The whole page area, margins included, takes taps.
                      behavior: HitTestBehavior.opaque,
                      onDoubleTapDown: (details) =>
                          _doubleTapAt = details.localPosition,
                      onDoubleTap: _toggleZoom,
                      child: Center(
                        child: Image.memory(
                          widget.book.pages[index],
                          fit: BoxFit.contain,
                          cacheWidth: decodeWidth > 0 ? decodeWidth : null,
                          gaplessPlayback: true,
                          semanticLabel: 'Page ${index + 1}',
                        ),
                      ),
                    );
                    // Only the zoomed page gets a zoom handler; see the class
                    // comment for why it can't stay on all the time.
                    if (!_zoomed || index != _page) return page;
                    return InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 4,
                      onInteractionEnd: _onZoomEnd,
                      child: page,
                    );
                  },
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.enabled && _page > 0
                      ? () => _goTo(_page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
              ),
              if (widget.book.chapters.isEmpty)
                const SizedBox(width: 12)
              else
                IconButton(
                  tooltip: 'Contents',
                  onPressed: widget.enabled ? _showContents : null,
                  icon: const Icon(Icons.format_list_bulleted),
                ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !widget.enabled
                      ? null
                      : _isLast
                      ? widget.onFinish
                      : () => _goTo(_page + 1),
                  icon: Icon(_isLast ? Icons.check : Icons.chevron_right),
                  label: Text(_isLast ? 'Finish book' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
