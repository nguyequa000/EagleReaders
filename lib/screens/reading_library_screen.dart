import 'package:flutter/material.dart';

import '../reading_theme.dart';
import '../services/book_library.dart';
import 'book_cover.dart';
import 'book_shelf_screen.dart';
import 'reading_module_page.dart';

/// A child's shelf, to read from. Grown-ups add books in Manage Shelf
/// ([BookShelfScreen]).
class ReadingLibraryScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final BookLibrary? library;

  const ReadingLibraryScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.library,
  });

  @override
  State<ReadingLibraryScreen> createState() => _ReadingLibraryScreenState();
}

class _ReadingLibraryScreenState extends State<ReadingLibraryScreen> {
  late final _library = widget.library ?? BookLibrary(widget.childId);
  List<Book> _books = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
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
              const Text(
                'Ask a grown-up to add books to your shelf.',
                textAlign: TextAlign.center,
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
            onTap: () => _open(book),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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

  @override
  Widget build(BuildContext context) => Theme(
    data: readingTheme(context),
    child: Scaffold(
      appBar: AppBar(title: const Text('Reading Library')),
      body: SafeArea(child: _shelf()),
    ),
  );
}
