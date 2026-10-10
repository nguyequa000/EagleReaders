import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../reading_theme.dart';
import '../services/book_library.dart';
import '../services/child_profiles.dart';
import '../services/device_memory.dart';
import '../services/epub_metadata.dart';
import 'book_cover.dart';
import 'paged_text_view.dart';

/// Manage Shelf: the parent imports the family's books once, then chooses
/// which children each one is for, and can rename them.
class BookShelfScreen extends StatefulWidget {
  final BookShelf? shelf;

  /// Where the children to give books to come from.
  final ChildProfileStore? store;

  const BookShelfScreen({super.key, this.shelf, this.store});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen>
    with SingleTickerProviderStateMixin {
  /// Larger files are refused up front rather than risking running out of
  /// memory while the whole book is parsed.
  static const _maxEpubBytes = 150 * 1024 * 1024;

  late final _shelf = widget.shelf ?? BookShelf();
  late final _store = widget.store ?? ChildProfileStore();
  late final TabController _tabs;
  final _form = GlobalKey<FormState>();
  final _drafts = <_BookDraft>[];
  List<Book> _books = [];
  List<ChildProfile> _children = [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  /// What [_getReady] is doing, shown above the tabs; null when idle.
  String? _status;
  Future<void> _readying = Future.value();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refresh().then((_) {
      // Books imported before big ones were got ready at import.
      for (final book in _books) {
        _queueGetReady(book);
      }
    });
  }

  Future<void> _refresh() async {
    try {
      final books = await _shelf.load();
      books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      List<ChildProfile> children;
      try {
        children = await _store.load();
      } catch (_) {
        children = [];
      }
      if (mounted) {
        setState(() {
          _books = books;
          _children = children;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'The shelf could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Does now what the reader would otherwise do the first time a child
  /// opens a big illustrated book: makes the lighter copy the paged reader
  /// reads (see [BookLibrary.lighterCopy]). One book at a time.
  Future<void> _queueGetReady(Book book) =>
      _readying = _readying.then((_) => _getReady(book));

  Future<void> _getReady(Book book) async {
    if (!pagedTextSupported) return;
    try {
      final limit = await pagedBookLimit();
      if (await File(book.filePath).length() <= limit) return;
      if (await File(BookLibrary.lighterPath(book)).exists()) return;
      if (mounted) {
        setState(() => _status = 'Getting "${book.title}" ready to read…');
      }
      // Picture books are shown a page image at a time, not by the paged
      // reader, so they never need the copy.
      if (await _shelf.isPictureBook(book)) return;
      await BookLibrary.lighterCopy(book, maxBytes: limit);
    } catch (e) {
      // The reader tries again when the book is opened.
      debugPrint('Could not get ${book.title} ready: $e');
    } finally {
      if (mounted) setState(() => _status = null);
    }
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
        // The title the book gives itself, or failing that its file name
        // tidied up.
        final info = path == null
            ? readEpubInfo(bytes)
            : await readEpubInfoOffThread(path);
        if (!mounted) return;
        final title = info?.title ?? '';
        _drafts.add(
          _BookDraft(
            file.name,
            bytes,
            title: title.isEmpty ? titleFromFileName(file.name) : title,
            author: info?.author ?? '',
            readers: {for (final child in _children) child.id},
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
        final book = await _shelf.add(
          fileName: draft.name,
          bytes: draft.bytes,
          title: draft.title.text,
          author: draft.author.text,
          readers: draft.readers,
        );
        added++;
        if (!mounted) return;
        // Remove each successful import immediately; a later failure must not
        // re-import earlier files when the user retries.
        setState(() => _drafts.remove(draft));
        WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
        // So the child doesn't wait the first time they open it.
        await _queueGetReady(book);
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

  Future<void> _rename(Book book) async {
    final renamed = await showDialog<({String title, String author})>(
      context: context,
      builder: (_) => _RenameDialog(book),
    );
    if (renamed == null) return;
    try {
      await _shelf.rename(
        book.id,
        title: renamed.title,
        author: renamed.author,
      );
    } catch (_) {
      _message('Could not rename this book. Please try again.');
    }
    await _refresh();
  }

  Future<void> _chooseReaders(Book book) async {
    if (_children.isEmpty) {
      _message('Add a child first, then you can give them books.');
      return;
    }
    final readers = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ReadersDialog(book, _children),
    );
    if (readers == null) return;
    try {
      await _shelf.setReaders(book.id, readers);
    } catch (_) {
      _message('Could not save who reads this book. Please try again.');
    }
    await _refresh();
  }

  Future<void> _remove(Book book) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text(
          'Remove "${book.title}" from the shelf? Every child it was given to '
          'loses it, and their place in it.',
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
      await _shelf.remove(book);
      await _refresh();
    } catch (_) {
      _message('Could not completely remove this book. Please try again.');
      await _refresh();
    }
  }

  String _readersLabel(Book book) {
    final names = [
      for (final child in _children)
        if (book.readers.contains(child.id)) child.name,
    ];
    return names.isEmpty
        ? 'Not given to anyone yet'
        : 'For ${names.join(', ')}';
  }

  Widget _shelfTab() {
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
              const Text(
                'Import EPUB books, then choose which children each one is '
                'for.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _tabs.animateTo(1),
                icon: const Icon(Icons.add),
                label: const Text('Import the first book'),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 400,
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
            onTap: () => _chooseReaders(book),
            onLongPress: () => _remove(book),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.expand(
                          child: BookCover(
                            path: book.coverPath,
                            fallback: bookCoverFallback(book),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (book.author.isNotEmpty)
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    _readersLabel(book),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: readingGreen),
                  ),
                  // Their own row: beside the label they left it no room on
                  // a phone's two-column grid.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Rename ${book.title}',
                        onPressed: () => _rename(book),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Choose who reads ${book.title}',
                        onPressed: () => _chooseReaders(book),
                        icon: const Icon(Icons.group_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove ${book.title}',
                        onPressed: () => _remove(book),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _importTab() => SingleChildScrollView(
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
                'Fill the family shelf',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose EPUB files from your device. Check each title and '
                'author, and who it is for, before adding them.',
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
              for (final draft in _drafts) _draftCard(draft),
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

  Widget _draftCard(_BookDraft draft) => Card(
    key: ObjectKey(draft),
    elevation: 0,
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(draft.name, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Discard ${draft.name}',
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _drafts.remove(draft));
                        WidgetsBinding.instance.addPostFrameCallback(
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
            validator: (value) => value == null || value.trim().isEmpty
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
          const SizedBox(height: 16),
          const Text(
            'Who is it for?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_children.isEmpty)
            const Text(
              'No children yet. You can give it to them once they are added.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final child in _children)
                  FilterChip(
                    label: Text(child.name),
                    selected: draft.readers.contains(child.id),
                    onSelected: _busy
                        ? null
                        : (on) => setState(
                            () => on
                                ? draft.readers.add(child.id)
                                : draft.readers.remove(child.id),
                          ),
                  ),
              ],
            ),
        ],
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
        title: const Text('Manage Shelf'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Shelf'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Import'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_status case final status?)
              Material(
                color: readingGreen.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(status)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_shelfTab(), _importTab()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The first letter of [book]'s title, for a book without a cover.
Widget bookCoverFallback(Book book) => ColoredBox(
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

class _BookDraft {
  final String name;
  final Uint8List bytes;
  final TextEditingController title, author;
  final Set<String> readers;
  _BookDraft(
    this.name,
    this.bytes, {
    required String title,
    required String author,
    required this.readers,
  }) : title = TextEditingController(text: title),
       author = TextEditingController(text: author);
  void dispose() {
    title.dispose();
    author.dispose();
  }
}

class _RenameDialog extends StatefulWidget {
  final Book book;
  const _RenameDialog(this.book);

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(text: widget.book.author);

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (title: _title.text, author: _author.text));
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename book'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Book title',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a book title.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _author,
              decoration: const InputDecoration(
                labelText: 'Author (optional)',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

class _ReadersDialog extends StatefulWidget {
  final Book book;
  final List<ChildProfile> children;
  const _ReadersDialog(this.book, this.children);

  @override
  State<_ReadersDialog> createState() => _ReadersDialogState();
}

class _ReadersDialogState extends State<_ReadersDialog> {
  late final _readers = {...widget.book.readers};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Who is "${widget.book.title}" for?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in widget.children)
            CheckboxListTile(
              value: _readers.contains(child.id),
              title: Text(child.name),
              secondary: Text(
                child.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              onChanged: (on) => setState(
                () => on == true
                    ? _readers.add(child.id)
                    : _readers.remove(child.id),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _readers),
        child: const Text('Save'),
      ),
    ],
  );
}

/// One child's books, chosen from the family shelf (Child Profile → Choose
/// books). Importing happens in [BookShelfScreen].
class ChildShelfScreen extends StatefulWidget {
  final String childId, childName;
  final BookShelf? shelf;
  final ChildProfileStore? store;

  const ChildShelfScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.shelf,
    this.store,
  });

  @override
  State<ChildShelfScreen> createState() => _ChildShelfScreenState();
}

class _ChildShelfScreenState extends State<ChildShelfScreen> {
  late final _shelf = widget.shelf ?? BookShelf();
  List<Book>? _books;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    List<Book> books;
    try {
      books = await _shelf.load();
    } catch (_) {
      books = [];
    }
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (mounted) setState(() => _books = books);
  }

  Future<void> _toggle(Book book, bool on) async {
    try {
      await _shelf.setReaders(book.id, {
        ...book.readers.where((id) => id != widget.childId),
        if (on) widget.childId,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    }
    await _refresh();
  }

  Future<void> _manageShelf() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BookShelfScreen(shelf: _shelf, store: widget.store),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    return Theme(
      data: readingTheme(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text("${widget.childName}'s Books"),
          actions: [
            TextButton.icon(
              onPressed: _manageShelf,
              icon: const Icon(Icons.library_add),
              label: const Text('Manage Shelf'),
            ),
          ],
        ),
        body: books == null
            ? const Center(child: CircularProgressIndicator())
            : books.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'The family shelf is empty.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Import books in Manage Shelf, then tick the ones '
                        'for this child here.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _manageShelf,
                        icon: const Icon(Icons.library_add),
                        label: const Text('Import books'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Tick the books ${widget.childName} can read.'),
                  ),
                  for (final book in books)
                    CheckboxListTile(
                      value: book.readers.contains(widget.childId),
                      onChanged: (on) => _toggle(book, on == true),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 40,
                          height: 56,
                          child: BookCover(
                            path: book.coverPath,
                            fallback: ColoredBox(
                              color: readingGreen.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.menu_book,
                                color: readingGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: book.author.isEmpty ? null : Text(book.author),
                    ),
                ],
              ),
      ),
    );
  }
}
