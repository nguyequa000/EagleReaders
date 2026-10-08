import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:epub_view/epub_view.dart';
// epub_view exposes EpubViewChapter in its API but omits it from the barrel.
// ignore: implementation_imports
import 'package:epub_view/src/data/models/chapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/activity_service.dart';
import '../services/book_library.dart';
import '../services/device_memory.dart';
import '../services/story_generator.dart';
import '../reading_theme.dart';
import 'chapter_quiz.dart';
import 'comprehension_screen.dart';
import 'paged_text_view.dart';
import 'picture_book_view.dart';

class ReadingModulePage extends StatefulWidget {
  final String childId;
  final String childName;
  final Book book;
  final BookLibrary library;

  const ReadingModulePage({
    super.key,
    required this.childId,
    required this.childName,
    required this.book,
    required this.library,
  });

  /// Writes the end-of-book quiz; tests swap in a fake.
  @visibleForTesting
  static Future<List<ComprehensionQuestion>> Function(
    String title,
    List<String> chapterHtml,
  )
  generateQuestions = generateBookQuestions;

  /// Writes a chapter's quiz from its text; tests swap in a fake.
  @visibleForTesting
  static Future<List<ComprehensionQuestion>> Function(
    String bookTitle,
    String chapterTitle,
    List<String> chapterHtml,
  )
  writeChapterQuiz = generateChapterQuestions;

  /// Writes a picture-book chapter's quiz from its pages; tests swap in a
  /// fake.
  @visibleForTesting
  static Future<List<ComprehensionQuestion>> Function(
    String bookTitle,
    String chapterTitle,
    List<Uint8List> pages,
  )
  writePictureQuiz = generatePictureChapterQuestions;

  @override
  State<ReadingModulePage> createState() => _ReadingModulePageState();
}

class _ReadingModulePageState extends State<ReadingModulePage> {
  SharedPreferences? _prefs;
  EpubController? _controller;
  EpubBook? _document;

  /// Set instead of [_controller] for picture books (comics etc.), which are
  /// shown one page image at a time; [_chapterIndex] is then the page index.
  PictureBook? _pictureBook;

  /// Set instead of [_controller] for text books on phones, which are shown
  /// page by page (see [PagedTextView]).
  PagedTextBook? _pagedText;
  String? _pagedInitialCfi;
  String? _pagedChapterTitle;
  List<EpubViewChapter> _chapters = [];
  String get _bookTitle => widget.book.title;
  String? _loadError;

  /// A big illustrated book is getting its lighter copy made (see
  /// [BookLibrary.lighterCopy]); only happens the first time it's opened.
  bool _preparing = false;
  int _chapterIndex = 0;
  bool _busy = false;
  bool _ready = false;
  double _fontSize = 20;
  double _lineHeight = 1.6;
  String _readerTheme = 'paper';
  int? _lastSavedPosition;
  DateTime? _sessionStart;
  // The Finish book button fades out while the child scrolls the text.
  bool _controlsVisible = true;
  Timer? _showControlsTimer;

  /// End-of-chapter quizzes for the scrolling reader (the picture and paged
  /// views run their own and report through [_showChapterQuiz]).
  ChapterQuizTrigger? _scrollQuiz;
  bool _chapterQuizOpen = false;

  /// Chapter changes until this time come from a Contents jump, which scrolls
  /// past chapters on the way and mustn't count as finishing them.
  DateTime _jumpSettlesAt = DateTime(0);

  bool get _canNavigate => _ready && !_busy;
  bool get _isLast => _chapterIndex == _chapters.length - 1;
  String get _positionKey => widget.library.positionKey(widget.book);
  Color get _background => switch (_readerTheme) {
    'dark' => readingDark,
    'white' => Colors.white,
    _ => readingPaper,
  };
  Color get _foreground => _readerTheme == 'dark'
      ? const Color(0xFFF0F0F0)
      : const Color(0xFF2E2E2E);
  String get _chapterLabel => _pagedText != null
      ? _pagedChapterTitle ?? ''
      : _pictureBook != null
      ? _pictureBook!.chapterAt(_chapterIndex)?.title ??
            'Page ${_chapterIndex + 1} of ${_pictureBook!.pages.length}'
      : _chapters.isEmpty
      ? 'Opening book…'
      : (_chapters[_chapterIndex].title?.trim().isNotEmpty ?? false)
      ? _chapters[_chapterIndex].title!.trim()
      : 'Chapter ${_chapterIndex + 1}';
  String get _chaptersLeftLabel =>
      switch (_chapters.length - _chapterIndex - 1) {
        <= 0 => 'Last chapter!',
        1 => '1 chapter left',
        final left => '$left chapters left',
      };

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _fontSize = (prefs.getDouble('font_size') ?? 20).clamp(14, 32);
        _lineHeight = (prefs.getDouble('line_height') ?? 1.6).clamp(1.2, 2.2);
        _readerTheme = prefs.getString('reader_theme') ?? 'paper';
      });
      _loadBook();
    });
  }

  Future<void> _loadBook() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      await _openBook();
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError =
              'Could not open this EPUB. It may be missing, damaged or unsupported.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBook() async {
    final path = widget.book.filePath;
    final size = await File(path).length();
    if (size == 0) throw const FormatException('Empty EPUB');
    // Not kept in a local: a big book's bytes would otherwise stay alive
    // next to the parsed book while its lighter copy is made.
    final raw = await EpubDocument.openData(await File(path).readAsBytes());
    // Before flatten(), which rewrites the contents tree in place.
    final pictures = readPictureBook(raw);
    final book = BookLibrary.flatten(raw, allowEmpty: pictures != null);
    String? pagedPath;
    if (pictures == null && pagedTextSupported) {
      // The paged reader hands the whole book to its web view in one go, so
      // how big a book it can take depends on the phone's memory.
      final limit = await pagedBookLimit();
      if (size <= limit) {
        pagedPath = path;
      } else {
        // Usually big because of its pictures: read a copy with them
        // re-saved smaller rather than falling back to scrolling.
        if (mounted) setState(() => _preparing = true);
        try {
          pagedPath = await BookLibrary.lighterCopy(
            widget.book,
            maxBytes: limit,
          );
        } catch (e) {
          // The scrolling reader still works.
          debugPrint('Could not make a lighter copy of this book: $e');
        }
        if (mounted) setState(() => _preparing = false);
      }
    }
    final pagedText = pagedPath == null
        ? null
        : PagedTextBook(PagedTextSource.file(pagedPath), book);
    if (pagedText != null) {
      // The paged reader draws pictures from the file, so the parsed copies
      // are dead weight; for an illustrated book they're most of its size,
      // and keeping them next to the copy the reader hands its web view ran
      // the app out of memory.
      final content = book.Content;
      content?.Images?.clear();
      content?.Fonts?.clear();
      content?.AllFiles?.removeWhere((_, file) => file is EpubByteContentFile);
      book.CoverImage = null;
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    _savePosition();
    await _endReadingSession();
    if (!mounted) return;
    final oldController = _controller;
    final savedPosition = prefs.getInt(_positionKey);
    setState(() {
      _prefs = prefs;
      _document = book;
      _controller = pictures == null && pagedText == null
          ? EpubController(document: Future.value(book))
          : null;
      _pictureBook = pictures;
      _pagedText = pagedText;
      _pagedInitialCfi = prefs.getString(widget.library.cfiKey(widget.book));
      _pagedChapterTitle = null;
      _chapters = [];
      _chapterIndex = pictures == null
          ? 0
          : (savedPosition ?? 0).clamp(0, pictures.pages.length - 1);
      _lastSavedPosition = savedPosition;
      // Only the scrolling reader needs a layout pass before navigating.
      _ready = _controller == null;
    });
    // Let the old EpubView detach before disposing its notifiers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disposeController(oldController);
    });
    if (_controller == null) {
      if (pictures != null) {
        _saveShelfProgress(_chapterIndex + 1, pictures.pages.length);
      }
      _startReading();
    }
  }

  void _onDocumentLoaded(EpubBook book) {
    if (!mounted) return;
    final controller = _controller!;
    setState(() => _chapters = controller.tableOfContents());
    _scrollQuiz = ChapterQuizTrigger([
      for (final c in _chapters) (title: c.title?.trim() ?? '', depth: 0),
    ]);
    // Resume by paragraph index (epub_view CFIs don't round-trip reliably).
    // _ready stays false until then, so early scroll events can't overwrite it.
    final saved = _lastSavedPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _controller) return;
      if (saved != null) controller.jumpTo(index: saved);
      setState(() => _ready = true);
      _saveShelfProgress(_chapterIndex + 1, _chapters.length);
    });
    _startReading();
  }

  void _startReading() {
    _sessionStart = ActivityService.instance.startSession();
    unawaited(
      ActivityService.instance.logEvent(widget.childId, 'book_opened', {
        'title': _bookTitle,
      }),
    );
  }

  void _savePosition() {
    if (!_ready) return;
    final position = _pictureBook != null
        ? _chapterIndex
        : _controller?.currentValue?.position.index;
    if (position == null || position == _lastSavedPosition) return;
    _lastSavedPosition = position;
    _prefs?.setInt(_positionKey, position);
  }

  void _saveShelfProgress(int chapter, int total) {
    if (total < 1) return;
    unawaited(
      widget.library
          .markOpened(widget.book, chapter: chapter, total: total)
          .catchError((Object _) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not update your shelf progress.'),
              ),
            );
          }),
    );
  }

  void _goToChapter(int index) {
    if (!_canNavigate || index < 0 || index >= _chapters.length) return;
    _controller!.scrollTo(index: _chapters[index].startIndex);
  }

  Future<void> _finishBook() async {
    if (!_canNavigate) return;
    setState(() => _busy = true);
    _savePosition();
    await _endReadingSession();
    await ActivityService.instance.logEvent(widget.childId, 'book_finished', {
      'title': _bookTitle,
    });
    if (!mounted) return;
    final title = _bookTitle;
    final chapterHtml = [
      for (final chapter in _document?.Chapters ?? <EpubChapter>[])
        chapter.HtmlContent ?? '',
    ];
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComprehensionScreen(
          childId: widget.childId,
          childName: widget.childName,
          bookTitle: title,
          chapterNumber: _chapterIndex + 1,
          generateQuestions: () =>
              ReadingModulePage.generateQuestions(title, chapterHtml),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _sessionStart = ActivityService.instance.startSession();
  }

  /// Shows the quiz for a chapter the child just read past: Gemini writes it
  /// from what the chapter contains ([from] to [to], in the current view's
  /// units: sections, spine files or pages). Reading time pauses while it is
  /// open, and it can be skipped.
  Future<void> _showChapterQuiz(
    FinishedChapter chapter,
    int from,
    int to,
  ) async {
    // Deliberately not [_busy]: that shows a progress bar above the book,
    // and the few pixels it takes resize the paged reader's web view, which
    // makes epub.js jump back to where the book was opened.
    if (!mounted || _busy || _chapterQuizOpen) return;
    _chapterQuizOpen = true;
    _savePosition();
    await _endReadingSession();
    if (mounted) {
      final write = _chapterQuizWriter(chapter, from, to);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ComprehensionScreen(
            childId: widget.childId,
            childName: widget.childName,
            bookTitle: _bookTitle,
            chapterNumber: chapter.number,
            chapterTitle: chapter.title,
            skippable: true,
            generateQuestions: () => _cachedQuiz(chapter.number, write),
          ),
        ),
      );
    }
    _chapterQuizOpen = false;
    if (!mounted) return;
    _sessionStart = ActivityService.instance.startSession();
  }

  /// What Gemini is given for [chapter]: the page images of a picture book,
  /// otherwise the chapter's text.
  Future<List<ComprehensionQuestion>> Function() _chapterQuizWriter(
    FinishedChapter chapter,
    int from,
    int to,
  ) {
    final title = _bookTitle;
    final pictures = _pictureBook;
    if (pictures != null) {
      final pages = pictures.pages.sublist(from, to);
      return () =>
          ReadingModulePage.writePictureQuiz(title, chapter.title, pages);
    }
    final html = _pagedText != null
        ? _pagedText!.spineHtml.sublist(from, to)
        : [
            for (final section in (_document?.Chapters ?? <EpubChapter>[])
                .sublist(from, to))
              section.HtmlContent ?? '',
          ];
    return () => ReadingModulePage.writeChapterQuiz(title, chapter.title, html);
  }

  /// A chapter's quiz is written once and kept, so reading the chapter again
  /// doesn't spend the free tier's few requests a minute.
  Future<List<ComprehensionQuestion>> _cachedQuiz(
    int chapter,
    Future<List<ComprehensionQuestion>> Function() write,
  ) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final key = widget.library.quizKey(widget.book, chapter);
    final saved = prefs.getString(key);
    if (saved != null) {
      try {
        return [
          for (final q in jsonDecode(saved) as List)
            ComprehensionQuestion.fromJson(Map<String, dynamic>.from(q)),
        ];
      } catch (_) {
        // A damaged entry is just written again.
      }
    }
    final questions = await write();
    await prefs.setString(
      key,
      jsonEncode([for (final q in questions) q.toJson()]),
    );
    return questions;
  }

  Future<void> _endReadingSession() async {
    final start = _sessionStart;
    _sessionStart = null; // Clear before awaiting to prevent duplicate flushes.
    if (start == null) return;
    await ActivityService.instance.logReadingSession(
      widget.childId,
      start: start,
      title: _bookTitle,
      bookType: 'epub',
    );
  }

  void _showContents() {
    if (!_canNavigate) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          itemCount: _chapters.length,
          itemBuilder: (_, index) => ListTile(
            leading: Text('${index + 1}'),
            title: Text(_chapters[index].title ?? 'Chapter ${index + 1}'),
            selected: index == _chapterIndex,
            onTap: () {
              Navigator.pop(sheetContext);
              _jumpSettlesAt = DateTime.now().add(const Duration(seconds: 2));
              _goToChapter(index);
            },
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reading Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ListTile(
                  title: Text('Font Size: ${_fontSize.round()}'),
                  subtitle: Slider(
                    min: 14,
                    max: 32,
                    value: _fontSize,
                    label: '${_fontSize.round()}',
                    onChanged: (value) {
                      setState(() => _fontSize = value);
                      setSheetState(() {});
                      _prefs?.setDouble('font_size', value);
                    },
                  ),
                ),
                ListTile(
                  title: Text(
                    'Line Spacing: ${_lineHeight.toStringAsFixed(1)}',
                  ),
                  subtitle: Slider(
                    min: 1.2,
                    max: 2.2,
                    value: _lineHeight,
                    label: _lineHeight.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => _lineHeight = value);
                      setSheetState(() {});
                      _prefs?.setDouble('line_height', value);
                    },
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final theme in ['paper', 'white', 'dark'])
                      ChoiceChip(
                        label: Text(
                          '${theme[0].toUpperCase()}${theme.substring(1)} Theme',
                        ),
                        selected: _readerTheme == theme,
                        onSelected: (_) {
                          setState(() => _readerTheme = theme);
                          setSheetState(() {});
                          _prefs?.setString('reader_theme', theme);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Center(
    child: _loadError == null && _preparing
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Getting this big book ready…\n'
                'This only happens the first time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _foreground),
              ),
            ],
          )
        : _loadError == null
        ? const CircularProgressIndicator()
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _foreground),
                ),
                TextButton(
                  onPressed: _loadBook,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
  );

  bool _onUserScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    _showControlsTimer?.cancel();
    if (n.direction == ScrollDirection.idle) {
      _showControlsTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _controlsVisible = true);
      });
    } else if (_controlsVisible) {
      setState(() => _controlsVisible = false);
    }
    return false;
  }

  Widget _buildPictureBook() => PictureBookView(
    key: ValueKey(_pictureBook),
    book: _pictureBook!,
    initialPage: _chapterIndex,
    enabled: _canNavigate,
    background: _background,
    accent: readingGreen,
    onPageChanged: (page) {
      setState(() => _chapterIndex = page);
      _savePosition();
      _saveShelfProgress(page + 1, _pictureBook!.pages.length);
    },
    onFinish: _finishBook,
    onChapterEnd: _showChapterQuiz,
  );

  Widget _buildPagedText() => PagedTextView(
    key: ValueKey(_pagedText),
    book: _pagedText!,
    initialCfi: _pagedInitialCfi,
    fontSize: _fontSize,
    lineHeight: _lineHeight,
    background: _background,
    foreground: _foreground,
    accent: readingGreen,
    enabled: _canNavigate,
    onRelocated: (cfi, chapterTitle) {
      _prefs?.setString(widget.library.cfiKey(widget.book), cfi);
      if (chapterTitle != _pagedChapterTitle) {
        setState(() => _pagedChapterTitle = chapterTitle);
        final spine = spineIndexOfCfi(cfi);
        if (spine != null) {
          _saveShelfProgress(spine + 1, _pagedText!.spine.length);
        }
      }
    },
    onFinish: _finishBook,
    onChapterEnd: _showChapterQuiz,
  );

  Widget _buildReader() => ColoredBox(
    color: _background,
    child: EpubView(
      key: ValueKey(_controller),
      controller: _controller!,
      onDocumentLoaded: _onDocumentLoaded,
      onChapterChanged: (value) {
        if (!mounted || !_ready || value == null || _chapters.isEmpty) return;
        final index = (value.chapterNumber - 1).clamp(0, _chapters.length - 1);
        // Repeated layout callbacks must not cause an endless rebuild loop.
        if (index != _chapterIndex) {
          setState(() => _chapterIndex = index);
          _saveShelfProgress(index + 1, _chapters.length);
        }
        _savePosition();
        final finished = _scrollQuiz?.moveTo(
          index,
          pageTurn: DateTime.now().isAfter(_jumpSettlesAt),
        );
        if (finished != null) {
          // Sections match contents entries one to one in this reader.
          _showChapterQuiz(finished, finished.entry, finished.end);
        }
      },
      onDocumentError: (_) {
        if (!mounted) return;
        setState(() => _ready = false);
      },
      builders: EpubViewBuilders<DefaultBuilderOptions>(
        options: DefaultBuilderOptions(
          loaderSwitchDuration: const Duration(milliseconds: 150),
          paragraphPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          textStyle: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            color: _foreground,
          ),
        ),
        loaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _) => const Center(
          child: Text(
            'This EPUB could not be displayed. Return to your library and try another book.',
          ),
        ),
        chapterDividerBuilder: (chapter) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            chapter.Title ?? '',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.bold,
              color: _foreground,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildProgressTracker() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Chapter ${_chapterIndex + 1} of ${_chapters.length}',
          style: TextStyle(fontWeight: FontWeight.w600, color: _foreground),
        ),
        const SizedBox(height: 6),
        // Read-only tracker: shows how far along the child is; it never
        // navigates. Use Contents to move between chapters.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_chapterIndex + 1) / _chapters.length,
            minHeight: 4,
            color: readingGreen,
            backgroundColor: readingGreen.withValues(alpha: 0.15),
            semanticsLabel: 'Reading progress',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _chaptersLeftLabel,
          style: TextStyle(color: _foreground, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildFinishButton() => IgnorePointer(
    ignoring: !_controlsVisible,
    child: AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: FilledButton.icon(
            onPressed: _canNavigate ? _finishBook : null,
            icon: const Icon(Icons.check),
            label: const Text('Finish book'),
          ),
        ),
      ),
    ),
  );

  void _disposeController(EpubController? controller) {
    controller?.dispose();
    // epub_view does not dispose this notifier itself.
    controller?.loadingState.dispose();
  }

  @override
  void dispose() {
    _showControlsTimer?.cancel();
    _savePosition();
    unawaited(_endReadingSession());
    _disposeController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: readingTheme(context, dark: _readerTheme == 'dark'),
    child: Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _foreground,
        title: Text(
          '$_bookTitle\n$_chapterLabel',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: 'Contents',
              onPressed: _canNavigate ? _showContents : null,
              icon: const Icon(Icons.format_list_bulleted),
            ),
          IconButton(
            tooltip: 'Reading settings',
            onPressed: _prefs == null ? null : _showSettings,
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_chapters.isNotEmpty) _buildProgressTracker(),
            // Keyed so inserting the tracker above never remounts the EpubView.
            Expanded(
              key: const ValueKey('reader-body'),
              child: _pictureBook != null
                  ? _buildPictureBook()
                  : _pagedText != null
                  ? _buildPagedText()
                  : _controller == null
                  ? _buildLoadingState()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        NotificationListener<UserScrollNotification>(
                          onNotification: _onUserScroll,
                          child: _buildReader(),
                        ),
                        if (_chapters.isNotEmpty && _isLast)
                          _buildFinishButton(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
