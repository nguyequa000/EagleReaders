import 'dart:async';

import 'package:epub_view/epub_view.dart';
// epub_view exposes EpubViewChapter in its API but omits it from the barrel.
// ignore: implementation_imports
import 'package:epub_view/src/data/models/chapter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/activity_service.dart';
import 'comprehension_screen.dart';

class ReadingModulePage extends StatefulWidget {
  final String childName;

  const ReadingModulePage({super.key, required this.childName});

  @override
  State<ReadingModulePage> createState() => _ReadingModulePageState();
}

class _ReadingModulePageState extends State<ReadingModulePage> {
  static const _green = Color(0xFF2E7D32);
  SharedPreferences? _prefs;
  EpubController? _controller;
  List<EpubViewChapter> _chapters = [];
  String _bookTitle = 'No book selected';
  int _chapterIndex = 0;
  bool _busy = false;
  bool _ready = false;
  double _fontSize = 20;
  double _lineHeight = 1.6;
  String _readerTheme = 'paper';
  int? _lastSavedPosition;
  DateTime? _sessionStart;

  bool get _canNavigate => _ready && !_busy;
  bool get _isLast => _chapterIndex == _chapters.length - 1;
  String get _positionKey => 'epub_position_${widget.childName}_$_bookTitle';
  Color get _background => switch (_readerTheme) {
    'dark' => const Color(0xFF1E1E1E),
    'white' => Colors.white,
    _ => const Color(0xFFF7F5F0),
  };
  Color get _foreground => _readerTheme == 'dark'
      ? const Color(0xFFF0F0F0)
      : const Color(0xFF2E2E2E);
  String get _chapterLabel => _chapters.isEmpty
      ? 'Import an .epub file to begin'
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
    });
  }

  Future<void> _load(Future<void> Function() open) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await open();
    } catch (_) {
      _showMessage(
        'Could not open this EPUB. It may be damaged or unsupported.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndLoadFile() => _load(() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.extension?.toLowerCase() != 'epub') {
      return _showMessage('Please choose an .epub file.');
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return _showMessage('The selected EPUB is empty or could not be read.');
    }
    await _openBook(EpubDocument.openData(bytes), file.name);
  });

  Future<void> _loadSampleBook() => _load(
    () => _openBook(
      EpubDocument.openAsset('assets/books/alice_in_wonderland.epub'),
      "Alice's Adventures in Wonderland",
    ),
  );

  Future<void> _openBook(Future<EpubBook> source, String title) async {
    // Parse before replacing the current book, so failed imports do not lose it.
    final book = await source;
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;

    // epub_view 3.2.0 miscalculates offsets for anchored TOC entries. Use one
    // section per XHTML file; keep all original HTML, links and embedded images.
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
          // Anchor must go: it is what triggers the bad offsets.
          sections.add(
            chapter
              ..Anchor = null
              ..SubChapters = [],
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
    _savePosition();
    await _endReadingSession();
    if (!mounted) return;
    final oldController = _controller;
    final savedPosition = prefs.getInt(
      'epub_position_${widget.childName}_$title',
    );
    setState(() {
      _prefs = prefs;
      _controller = EpubController(document: Future.value(book));
      _bookTitle = title;
      _chapters = [];
      _chapterIndex = 0;
      _lastSavedPosition = savedPosition;
      _ready = false;
    });
    // Let the old EpubView detach before disposing its notifiers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disposeController(oldController);
    });
  }

  void _onDocumentLoaded(EpubBook book) {
    if (!mounted) return;
    final controller = _controller!;
    setState(() => _chapters = controller.tableOfContents());
    // Resume by paragraph index (epub_view CFIs don't round-trip reliably).
    // _ready stays false until then, so early scroll events can't overwrite it.
    final saved = _lastSavedPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _controller) return;
      if (saved != null) controller.jumpTo(index: saved);
      setState(() => _ready = true);
    });
    _sessionStart = ActivityService.instance.startSession();
    unawaited(
      ActivityService.instance.logEvent(widget.childName, 'book_opened', {
        'title': _bookTitle,
      }),
    );
  }

  void _savePosition() {
    if (!_ready || _controller?.currentValue == null) return;
    final position = _controller!.currentValue!.position.index;
    if (position == _lastSavedPosition) return;
    _lastSavedPosition = position;
    _prefs?.setInt(_positionKey, position);
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
    await ActivityService.instance.logEvent(widget.childName, 'book_finished', {
      'title': _bookTitle,
    });
    if (!mounted) return;
    // This retains the existing demo quiz; it does not generate book questions.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComprehensionScreen(
          childName: widget.childName,
          bookTitle: _bookTitle,
          chapterNumber: _chapterIndex + 1,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _sessionStart = ActivityService.instance.startSession();
  }

  Future<void> _endReadingSession() async {
    final start = _sessionStart;
    _sessionStart = null; // Clear before awaiting to prevent duplicate flushes.
    if (start == null) return;
    await ActivityService.instance.logReadingSession(
      widget.childName,
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

  void _showMessage(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 64, color: _green),
          const SizedBox(height: 16),
          const Text(
            'Import an .epub file to start reading',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Read formatted chapters and illustrations — no text conversion.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndLoadFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose File'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _loadSampleBook,
            icon: const Icon(Icons.auto_stories),
            label: const Text("Try sample: Alice's Adventures in Wonderland"),
          ),
        ],
      ),
    ),
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
        if (index != _chapterIndex) setState(() => _chapterIndex = index);
        _savePosition();
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
            'This EPUB could not be displayed. Please import another book.',
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
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        // Read-only tracker: shows how far along the child is; it never
        // navigates. Use Previous/Next or Contents to move between chapters.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_chapterIndex + 1) / _chapters.length,
            minHeight: 10,
            color: _green,
            backgroundColor: _green.withValues(alpha: 0.15),
            semanticsLabel: 'Reading progress',
          ),
        ),
        const SizedBox(height: 4),
        Text(_chaptersLeftLabel),
      ],
    ),
  );

  Widget _buildFooter() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _canNavigate && _chapterIndex > 0
                ? () => _goToChapter(_chapterIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
        ),
        IconButton(
          tooltip: 'Contents',
          onPressed: _canNavigate ? _showContents : null,
          icon: const Icon(Icons.format_list_bulleted),
        ),
        Expanded(
          child: FilledButton.icon(
            onPressed: !_canNavigate
                ? null
                : _isLast
                ? _finishBook
                : () => _goToChapter(_chapterIndex + 1),
            icon: Icon(_isLast ? Icons.check : Icons.chevron_right),
            label: Text(_isLast ? 'Finish book' : 'Next'),
          ),
        ),
      ],
    ),
  );

  void _disposeController(EpubController? controller) {
    controller?.dispose();
    // epub_view does not dispose this notifier itself.
    controller?.loadingState.dispose();
  }

  @override
  void dispose() {
    _savePosition();
    unawaited(_endReadingSession());
    _disposeController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      title: Text(
        '$_bookTitle\n$_chapterLabel',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, height: 1.4),
      ),
      actions: [
        IconButton(
          tooltip: 'Import EPUB',
          onPressed: _busy ? null : _pickAndLoadFile,
          icon: const Icon(Icons.upload_file),
        ),
        IconButton(
          tooltip: 'Reading settings',
          onPressed: _prefs == null ? null : _showSettings,
          icon: const Icon(Icons.settings),
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
            child: _controller == null ? _buildEmptyState() : _buildReader(),
          ),
          if (_chapters.isNotEmpty) _buildFooter(),
        ],
      ),
    ),
  );
}
