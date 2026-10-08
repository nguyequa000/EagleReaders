import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../reading_theme.dart';
import '../services/book_library.dart';
import 'reading_module_page.dart';

class ReadingLibraryScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final BookLibrary? library;

  /// Parents can add and remove books; children only read them.
  final bool canManage;

  const ReadingLibraryScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.library,
    this.canManage = false,
  });

  @override
  State<ReadingLibraryScreen> createState() => _ReadingLibraryScreenState();
}

class _ReadingLibraryScreenState extends State<ReadingLibraryScreen>
    with SingleTickerProviderStateMixin {
  /// Larger files are refused up front rather than risking running out of
  /// memory while the whole book is parsed.
  static const _maxEpubBytes = 150 * 1024 * 1024;

  late final _library = widget.library ?? BookLibrary(widget.childId);
  late final TabController _tabs;
  final _form = GlobalKey<FormState>();
  final _drafts = <_BookDraft>[];
  List<Book> _books = [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final books = await _library.load();
      books.sort(
        (a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(
          a.lastOpenedAt ?? a.addedAt,
        ),
      );
      if (mounted) {
        setState(() {
          _books = books;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Your library could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _chooseFiles({bool sample = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final List<PlatformFile> files;
      if (sample) {
        final data = await rootBundle.load(
          'assets/books/alice_in_wonderland.epub',
        );
        files = [
          PlatformFile(
            name: 'alice_in_wonderland.epub',
            size: data.lengthInBytes,
            bytes: data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            ),
          ),
        ];
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['epub'],
          allowMultiple: true,
          // Only web needs the bytes (it has no file path). Elsewhere, having
          // the plugin send the bytes over the platform channel copies the
          // whole file inside the 192 MB Android Java heap, so large
          // image-heavy EPUBs crash the app with an OutOfMemoryError before
          // Dart can catch anything.
          withData: kIsWeb,
        );
        files = result?.files ?? [];
      }
      if (!mounted) return;
      for (final file in files) {
        if (file.extension?.toLowerCase() != 'epub') {
          _message('Please choose an .epub file.');
          continue;
        }
        if (file.size > _maxEpubBytes) {
          _message('This book is too large to open.');
          continue;
        }
        final path = file.path;
        final bytes =
            file.bytes ??
            (path == null ? null : await File(path).readAsBytes());
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) {
          _message('The selected EPUB is empty or could not be read.');
          continue;
        }
        _drafts.add(
          _BookDraft(
            file.name,
            bytes,
            title: sample ? "Alice's Adventures in Wonderland" : file.name,
            author: sample ? 'Lewis Carroll' : '',
          ),
        );
      }
    } catch (_) {
      _message('Could not read these files. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addBooks() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    var added = 0;
    try {
      for (final draft in List.of(_drafts)) {
        await _library.add(
          fileName: draft.name,
          bytes: draft.bytes,
          title: draft.title.text,
          author: draft.author.text,
        );
        added++;
        if (!mounted) return;
        // Remove each successful import immediately; a later failure must not
        // re-import earlier files when the user retries.
        setState(() => _drafts.remove(draft));
        WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
      }
      await _refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabs.animateTo(0);
      });
      _message(
        added == 1
            ? 'Book added to your shelf.'
            : '$added books added to your shelf.',
      );
    } on FormatException {
      _message('Could not open this EPUB. It may be damaged or unsupported.');
      await _refresh();
    } catch (_) {
      _message('Could not save this book. Please try again.');
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Book book) async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReadingModulePage(
          childId: widget.childId,
          childName: widget.childName,
          book: book,
          library: _library,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _remove(Book book) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text(
          'Remove "${book.title}" and its saved position from this shelf?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await _library.remove(book);
      await _refresh();
    } catch (_) {
      _message('Could not completely remove this book. Please try again.');
      await _refresh();
    }
  }

  Widget _shelf() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            TextButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_books.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 72,
                color: readingGreen,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your next adventure starts here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                widget.canManage
                    ? 'Add EPUB books for ${widget.childName} to read.'
                    : 'Ask a grown-up to add books to your shelf.',
                textAlign: TextAlign.center,
              ),
              if (widget.canManage) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _tabs.animateTo(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Add the first book'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 350,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            // Opening logs reading activity, so only the child opens books.
            onTap: widget.canManage ? null : () => _open(book),
            onLongPress: widget.canManage ? () => _remove(book) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.expand(
                        child: book.coverPath == null
                            ? _cover(book)
                            : Image.file(
                                File(book.coverPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _cover(book),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.canManage)
                        IconButton(
                          tooltip: 'Remove ${book.title}',
                          onPressed: () => _remove(book),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  if (book.author.isNotEmpty)
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: book.chaptersTotal == 0
                        ? 0
                        : book.chapter / book.chaptersTotal,
                    borderRadius: BorderRadius.circular(8),
                    semanticsLabel: '${book.title} chapter progress',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.chapter == 0
                        ? 'Ready to read'
                        : 'Chapter ${book.chapter} of ${book.chaptersTotal}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cover(Book book) => ColoredBox(
    color: readingGreen.withValues(alpha: 0.1),
    child: Center(
      child: Text(
        book.title.trim().substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w700,
          color: readingGreen,
        ),
      ),
    ),
  );

  Widget _addTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Make this shelf yours',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose EPUB files from your device. Edit the title and author before adding them.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _chooseFiles,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Choose File'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _chooseFiles(sample: true),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text(
                  "Try sample: Alice's Adventures in Wonderland",
                ),
              ),
              for (final draft in _drafts)
                Card(
                  key: ObjectKey(draft),
                  elevation: 0,
                  margin: const EdgeInsets.only(top: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                draft.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Discard ${draft.name}',
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() => _drafts.remove(draft));
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                            (_) => draft.dispose(),
                                          );
                                    },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: draft.title,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Book title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a book title.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: draft.author,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Author (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_drafts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _addBooks,
                    icon: const Icon(Icons.library_add),
                    label: const Text('Add to shelf'),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _tabs.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: readingTheme(context),
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.canManage ? "${widget.childName}'s Books" : 'Reading Library',
        ),
        bottom: widget.canManage
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(icon: Icon(Icons.menu_book_outlined), text: 'Shelf'),
                  Tab(icon: Icon(Icons.add_circle_outline), text: 'Add Book'),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: widget.canManage
            ? TabBarView(controller: _tabs, children: [_shelf(), _addTab()])
            : _shelf(),
      ),
    ),
  );
}

class _BookDraft {
  final String name;
  final Uint8List bytes;
  final TextEditingController title, author;
  _BookDraft(
    this.name,
    this.bytes, {
    required String title,
    required String author,
  }) : title = TextEditingController(text: title),
       author = TextEditingController(text: author);
  void dispose() {
    title.dispose();
    author.dispose();
  }
}
