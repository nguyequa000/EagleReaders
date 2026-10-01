import 'dart:convert';
import 'dart:io';

import 'package:epub_view/epub_view.dart' show EpubBook, EpubManifestItem;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart' as paged;

import 'chapter_quiz.dart';

/// Whether text books can be shown page by page on this platform.
///
/// The paged reader runs epub.js in a web view (`flutter_epub_viewer`), which
/// only supports Android and iOS. Everywhere else (web, desktop, widget
/// tests) text books keep the scrolling `EpubView` reader.
bool get pagedTextSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Where the paged reader loads a book from. It reads the file itself rather
/// than taking bytes, because `flutter_epub_viewer` only loads from a file,
/// URL or asset.
class PagedTextSource {
  const PagedTextSource.file(String path) : _path = path, _isAsset = false;
  const PagedTextSource.asset(String path) : _path = path, _isAsset = true;

  final String _path;
  final bool _isAsset;

  paged.EpubSource _load() => _isAsset
      ? paged.EpubSource.fromAsset(_path)
      : paged.EpubSource.fromFile(File(_path));
}

/// A text book ready for [PagedTextView].
class PagedTextBook {
  PagedTextBook(PagedTextSource source, EpubBook book)
    : _source = source._load(),
      spine = spineHrefs(book);

  final paged.EpubSource _source;

  /// The book's reading-order files, used to work out which chapter a page
  /// is in.
  final List<String> spine;
}

/// The book's spine (reading-order) files, as paths relative to the package
/// document, the same form the contents' hrefs use.
List<String> spineHrefs(EpubBook book) {
  final package = book.Schema?.Package;
  final manifest = {
    for (final item in package?.Manifest?.Items ?? const <EpubManifestItem>[])
      if (item.Id != null && item.Href != null) item.Id!: item.Href!,
  };
  return [
    for (final ref in package?.Spine?.Items ?? const [])
      if (manifest[ref.IdRef] case final href?) _normalize(href),
  ];
}

/// The spine index a CFI location points into: in `epubcfi(/6/8!/4/2)` the
/// second step, `/8`, is the 4th spine item (index 3). Null if [cfi] is not a
/// CFI.
int? spineIndexOfCfi(String cfi) {
  final match = RegExp(r'epubcfi\(/\d+/(\d+)').firstMatch(cfi);
  final step = int.tryParse(match?.group(1) ?? '');
  if (step == null || step < 2) return null;
  return step ~/ 2 - 1;
}

/// A contents entry of a paged text book.
class PagedChapter {
  const PagedChapter({
    required this.title,
    required this.href,
    required this.spineIndex,
    this.depth = 0,
  });

  final String title;

  /// What `EpubController.display` jumps to.
  final String href;

  /// Index into the spine, or null if the entry's file isn't in it.
  final int? spineIndex;

  /// Nesting level in the book's contents (0 = top level).
  final int depth;
}

/// Flattens the book's contents, matching each entry to its spine position.
List<PagedChapter> pagedChapters(
  List<paged.EpubChapter> toc,
  List<String> spine,
) {
  final result = <PagedChapter>[];
  void collect(List<paged.EpubChapter> entries, int depth) {
    for (final entry in entries) {
      final title = entry.title.trim();
      if (title.isNotEmpty) {
        result.add(
          PagedChapter(
            title: title,
            href: entry.href,
            spineIndex: _spineIndexOfHref(entry.href, spine),
            depth: depth,
          ),
        );
      }
      collect(entry.subitems, depth + 1);
    }
  }

  collect(toc, 0);
  return result;
}

/// The chapter a page in spine item [spineIndex] belongs to: the one
/// starting latest at or before it.
PagedChapter? pagedChapterAt(List<PagedChapter> chapters, int spineIndex) {
  PagedChapter? found;
  for (final chapter in chapters) {
    final start = chapter.spineIndex;
    if (start != null &&
        start <= spineIndex &&
        start >= (found?.spineIndex ?? 0)) {
      found = chapter;
    }
  }
  return found;
}

int? _spineIndexOfHref(String href, List<String> spine) {
  final path = _normalize(href.split('#').first);
  if (path.isEmpty) return null;
  for (var i = 0; i < spine.length; i++) {
    final item = spine[i];
    // Contents hrefs and manifest hrefs can be relative to different
    // folders, so allow either to be a suffix of the other.
    if (item == path || item.endsWith('/$path') || path.endsWith('/$item')) {
      return i;
    }
  }
  return null;
}

String _normalize(String path) {
  var decoded = path;
  try {
    decoded = Uri.decodeFull(path);
  } on ArgumentError {
    // A stray '%' that is not an escape; use the path as written.
  }
  return decoded.replaceAll('\\', '/').replaceFirst(RegExp(r'^(\./|/)+'), '');
}

String _cssColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Page-by-page reader for text books on phones: swipe or use the buttons to
/// turn a page, or jump to a chapter from Contents. Pagination is done by
/// epub.js, so pages reflow when the font size or line spacing changes.
class PagedTextView extends StatefulWidget {
  const PagedTextView({
    super.key,
    required this.book,
    required this.onRelocated,
    required this.onFinish,
    this.onChapterEnd,
    this.initialCfi,
    this.fontSize = 20,
    this.lineHeight = 1.6,
    this.background = Colors.white,
    this.foreground = Colors.black,
    this.accent = Colors.green,
    this.enabled = true,
  });

  final PagedTextBook book;

  /// Saved position to open at (from a previous [onRelocated]).
  final String? initialCfi;

  /// Called on every page turn with the new position and current chapter.
  final void Function(String cfi, String? chapterTitle) onRelocated;
  final VoidCallback onFinish;

  /// Called when the child turns the page out of a chapter, for its quiz.
  final ValueChanged<FinishedChapter>? onChapterEnd;

  final double fontSize;
  final double lineHeight;
  final Color background;
  final Color foreground;
  final Color accent;

  /// False while the parent is busy (e.g. finishing the book).
  final bool enabled;

  @override
  State<PagedTextView> createState() => _PagedTextViewState();
}

class _PagedTextViewState extends State<PagedTextView> {
  final _epub = paged.EpubController();
  List<PagedChapter> _chapters = [];
  PagedChapter? _chapter;
  bool _loaded = false;

  /// epub.js only knows how far through the book a page is once it has
  /// measured the whole book ("locations"), which takes a moment.
  bool _locationsReady = false;
  double _progress = 0;

  bool get _atEnd => _locationsReady && _progress >= 0.995;
  bool get _canTurn => widget.enabled && _loaded;

  paged.EpubTheme get _theme {
    final lineHeight = widget.lineHeight.toStringAsFixed(1);
    // !important: a book's own stylesheet often sets a white page and dark
    // text, which would leave the dark theme unreadable.
    final colors = {
      'background': '${_cssColor(widget.background)} !important',
      'color': '${_cssColor(widget.foreground)} !important',
    };
    return paged.EpubTheme.custom(
      backgroundDecoration: BoxDecoration(color: widget.background),
      foregroundColor: widget.foreground,
      customCss: {
        'html': colors,
        'body': {...colors, 'line-height': lineHeight},
        'p': {'line-height': lineHeight},
      },
    );
  }

  @override
  void didUpdateWidget(PagedTextView old) {
    super.didUpdateWidget(old);
    if (!_loaded) return;
    // Reading settings changed while the book is open.
    if (old.fontSize != widget.fontSize) {
      _epub.setFontSize(fontSize: widget.fontSize);
    }
    if (old.lineHeight != widget.lineHeight ||
        old.background != widget.background ||
        old.foreground != widget.foreground) {
      _epub.updateTheme(theme: _theme);
    }
  }

  /// Bumped on every relocation so a slow lookup for an earlier page can't
  /// overwrite the label of a later one.
  int _relocation = 0;

  ChapterQuizTrigger? _quiz;

  /// Page changes until this time come from a Contents jump (which displays
  /// twice, so reports twice) and don't count as finishing a chapter.
  DateTime _jumpSettlesAt = DateTime(0);

  Future<void> _onRelocated(paged.EpubLocation location) async {
    final relocation = ++_relocation;
    if (!mounted) return;
    setState(() => _progress = location.progress);
    final visible = await _visibleSpineIndex();
    final spineIndex = visible ?? spineIndexOfCfi(location.startCfi);
    if (!mounted || relocation != _relocation) return;
    // Where this page "is": normally its start, but on a section's first
    // page the start is the tail of the previous section, so use the end.
    final anchor =
        visible != null &&
            visible != spineIndexOfCfi(location.startCfi) &&
            visible == spineIndexOfCfi(location.endCfi)
        ? location.endCfi
        : location.startCfi;
    _rememberPosition(anchor);
    final chapter = spineIndex == null
        ? _chapter
        : pagedChapterAt(_chapters, spineIndex);
    setState(() => _chapter = chapter);
    final finished = _quiz?.moveTo(
      chapter == null ? null : _chapters.indexOf(chapter),
      pageTurn: DateTime.now().isAfter(_jumpSettlesAt),
    );
    if (finished != null) widget.onChapterEnd?.call(finished);
    widget.onRelocated(anchor, chapter?.title);
  }

  /// epub.js re-displays `rendition.location.start` whenever the view is
  /// resized, but on Android the package's custom swipe handling never
  /// updates that, so any resize (a progress bar appearing above the book, a
  /// rotation) jumped back to where the book was opened. Keep the real
  /// position in the page, and re-display it after epub.js's own jump.
  void _rememberPosition(String cfi) {
    _epub.webViewController?.evaluateJavascript(
      source: 'window.storySproutCfi = ${jsonEncode(cfi)};',
    );
  }

  static const _resizeHook = '''
if (!window.storySproutResizeHook) {
  window.storySproutResizeHook = true;
  rendition.on('resized', function () {
    window.flutter_inappwebview.callHandler('storySproutResized');
    var cfi = window.storySproutCfi;
    // Queued after epub.js's own display of the stale location.
    if (cfi) setTimeout(function () { rendition.display(cfi); }, 0);
  });
}''';

  /// The spine index of the section filling most of the screen.
  ///
  /// The location's CFIs aren't enough at section boundaries: on a section's
  /// first page the start CFI is the tail of the previous section, and on its
  /// last page the end CFI is the head of the next one. So ask epub.js which
  /// section view overlaps the viewport most.
  Future<int?> _visibleSpineIndex() async {
    try {
      final result = await _epub.webViewController?.evaluateJavascript(
        source: '''(function () {
  var best = -1, bestWidth = 0, width = window.innerWidth;
  rendition.manager.visible().forEach(function (view) {
    var r = view.element.getBoundingClientRect();
    var overlap = Math.min(r.right, width) - Math.max(r.left, 0);
    if (overlap > bestWidth) { bestWidth = overlap; best = view.section.index; }
  });
  return best;
})()''',
      );
      final index = (result as num?)?.toInt();
      return index == null || index < 0 ? null : index;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLocationsLoaded() async {
    if (!mounted) return;
    setState(() => _locationsReady = true);
    // Progress reported before this point was 0; fetch the real value.
    try {
      _onRelocated(await _epub.getCurrentLocation());
    } catch (_) {
      // The next page turn reports it anyway.
    }
  }

  /// Jumps to a contents entry.
  ///
  /// Displays it twice: the first display renders the target section and
  /// lays out its neighbour in front of it, which shifts the page after the
  /// scroll position was set, landing a few pages early (in the previous
  /// chapter); the second display, with layout settled, lands on the entry.
  void _jumpTo(String href) {
    _jumpSettlesAt = DateTime.now().add(const Duration(seconds: 2));
    final target = jsonEncode(href);
    _epub.webViewController?.evaluateJavascript(
      source:
          'rendition.display($target)'
          '.then(function () { return rendition.display($target); });',
    );
  }

  void _showContents() {
    final current = _chapter;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          itemCount: _chapters.length,
          itemBuilder: (_, index) {
            final chapter = _chapters[index];
            return ListTile(
              contentPadding: EdgeInsetsDirectional.only(
                start: 16 + 16.0 * chapter.depth,
                end: 16,
              ),
              title: Text(chapter.title),
              selected: identical(chapter, current),
              onTap: () {
                Navigator.pop(sheetContext);
                _jumpTo(chapter.href);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _locationsReady
                    ? '${(_progress * 100).round()}% read'
                    : 'Preparing pages…',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _locationsReady ? _progress : 0,
                  minHeight: 10,
                  color: widget.accent,
                  backgroundColor: widget.accent.withValues(alpha: 0.15),
                  semanticsLabel: 'Reading progress',
                ),
              ),
              // Always laid out, even before the chapter is known: the line
              // appearing later would shrink the web view, and any resize
              // re-paginates the book and shifts the page.
              const SizedBox(height: 4),
              Text(
                chapter?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: widget.background,
            child: paged.EpubViewer(
              epubController: _epub,
              epubSource: widget.book._source,
              // Opening at a saved spot on the very first section (the cover)
              // leaves epub.js's continuous layout unable to turn the page, so
              // start from the beginning instead; it is the same place.
              initialCfi: spineIndexOfCfi(widget.initialCfi ?? '') == 0
                  ? null
                  : widget.initialCfi,
              displaySettings: paged.EpubDisplaySettings(
                fontSize: widget.fontSize.round(),
                flow: paged.EpubFlow.paginated,
                // One page at a time on a phone, even in landscape.
                spread: paged.EpubSpread.none,
                snap: true,
                theme: _theme,
              ),
              onEpubLoaded: () {
                if (!mounted) return;
                // flutter_epub_viewer's loadBook() ends by re-registering the
                // theme with only a text colour, which drops our background
                // and line spacing; apply the full theme again.
                _epub.updateTheme(theme: _theme);
                // A resize makes epub.js jump away and back, which mustn't
                // look like turning pages (and so finishing a chapter).
                _epub.webViewController
                  ?..addJavaScriptHandler(
                    handlerName: 'storySproutResized',
                    callback: (_) => _jumpSettlesAt = DateTime.now().add(
                      const Duration(seconds: 2),
                    ),
                  )
                  ..evaluateJavascript(source: _resizeHook);
                setState(() => _loaded = true);
              },
              onChaptersLoaded: (toc) {
                if (!mounted) return;
                final chapters = pagedChapters(toc, widget.book.spine);
                setState(() => _chapters = chapters);
                _quiz = ChapterQuizTrigger([
                  for (final c in chapters) (title: c.title, depth: c.depth),
                ]);
              },
              onLocationLoaded: _onLocationsLoaded,
              onRelocated: _onRelocated,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canTurn ? _epub.prev : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
              ),
              IconButton(
                tooltip: 'Contents',
                onPressed: _canTurn && _chapters.isNotEmpty
                    ? _showContents
                    : null,
                icon: const Icon(Icons.format_list_bulleted),
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: !_canTurn
                      ? null
                      : _atEnd
                      ? widget.onFinish
                      : _epub.next,
                  icon: Icon(_atEnd ? Icons.check : Icons.chevron_right),
                  label: Text(_atEnd ? 'Finish book' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
