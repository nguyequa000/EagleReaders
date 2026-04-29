// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'comprehension_screen.dart';
import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ReadingModulePage extends StatefulWidget {
  const ReadingModulePage({super.key});

  @override
  State<ReadingModulePage> createState() => _ReadingModulePageState();
}

class _ReadingModulePageState extends State<ReadingModulePage> {
  String _bookTitle = 'No book selected';
  String _chapterLabel = 'Import a .txt or .epub file to begin';
  bool _isLoadingBook = false;
  bool _isBookLoaded = false;

  String _bookType = ''; // 'txt' or 'epub'

  // TXT state
  // ignore: unused_field
  String _bookContent = '';
  List<String> _pages = [];
  int _currentPage = 1;
  int _totalPages = 1;
  double _sliderValue = 0.0;

  // Reader settings
  double _fontSize = 20;
  double _lineHeight = 1.6;
  String _readerTheme = 'paper'; // paper, white, dark

  // EPUB state
  EpubController? _epubController;

  Color get _readerBackgroundColor {
    switch (_readerTheme) {
      case 'white':
        return Colors.white;
      case 'dark':
        return const Color(0xFF1E1E1E);
      case 'paper':
      default:
        return const Color(0xFFF7F5F0);
    }
  }

  Color get _readerTextColor {
    switch (_readerTheme) {
      case 'dark':
        return Colors.white;
      case 'white':
      case 'paper':
      default:
        return const Color(0xFF2E2E2E);
    }
  }

  Future<void> _pickAndLoadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileName = file.name;
      final ext = file.extension?.toLowerCase() ?? '';

      if (ext == 'txt') {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          _showMessage('Could not read .txt file bytes.');
          return;
        }
        await _loadTxtFromBytes(bytes, fileName);
        return;
      }

      if (ext == 'epub') {
        final path = file.path;
        if (path == null || path.isEmpty) {
          _showMessage('Could not access the selected EPUB file path.');
          return;
        }
        await _loadEpubFromPath(path, fileName);
        return;
      }

      _showMessage('Unsupported file type.');
    } catch (e) {
      _showMessage('Error picking file: $e');
    }
  }

  Future<void> _loadTxtFromBytes(Uint8List bytes, String fileName) async {
    try {
      setState(() {
        _isLoadingBook = true;
        _isBookLoaded = false;
        _bookType = '';
      });

      _epubController?.dispose();
      _epubController = null;

      final content = String.fromCharCodes(bytes).trim();

      if (content.isEmpty) {
        setState(() => _isLoadingBook = false);
        _showMessage('The selected .txt file is empty.');
        return;
      }

      final pages = _splitIntoPages(content);

      setState(() {
        _bookType = 'txt';
        _bookTitle = fileName;
        _bookContent = content;
        _pages = pages;
        _currentPage = 1;
        _totalPages = pages.isEmpty ? 1 : pages.length;
        _sliderValue = 0.0;
        _chapterLabel = 'Page $_currentPage / $_totalPages';
        _isBookLoaded = true;
        _isLoadingBook = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBook = false;
        _isBookLoaded = false;
      });
      _showMessage('Error loading .txt file: $e');
    }
  }

  /* Future<void> _loadEpubFromPath(String path, String fileName) async {
    try {
      setState(() {
        _isLoadingBook = true;
        _isBookLoaded = false;
        _bookType = '';
      });

      _epubController?.dispose();

      final controller = EpubController(
        document: EpubDocument.openFile(File(path)),
      );

      setState(() {
        _epubController = controller;
        _bookType = 'epub';
        _bookTitle = fileName;
        _chapterLabel = 'Opening EPUB...';
        _bookContent = '';
        _pages = [];
        _currentPage = 1;
        _totalPages = 1;
        _sliderValue = 0.0;
        _isBookLoaded = true;
        _isLoadingBook = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBook = false;
        _isBookLoaded = false;
      });
      _showMessage('Error loading EPUB: $e');
    }
  } */

 Future<void> _loadEpubFromPath(String path, String fileName) async {
  try {
    setState(() {
      _isLoadingBook = true;
      _isBookLoaded = false;
      _bookType = '';
    });

    _epubController?.dispose();
    _epubController = null;

    // Extract text from all EPUB chapters
    final epubBook = await EpubDocument.openFile(File(path));
    final StringBuffer buffer = StringBuffer();

    for (final chapter in epubBook.Chapters ?? []) {
      if (chapter.Title != null) {
        buffer.writeln('\n\n${chapter.Title}\n');
      }
      buffer.writeln(chapter.HtmlContent ?? '');

      for (final sub in chapter.SubChapters ?? []) {
        if (sub.Title != null) {
          buffer.writeln('\n\n${sub.Title}\n');
        }
        buffer.writeln(sub.HtmlContent ?? '');
      }
    }

    // Strip HTML tags
    final rawText = buffer
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), '\n\n')
        .trim();

    final pages = _splitIntoPages(rawText);

    setState(() {
      _bookType = 'txt'; // treat as txt now that it's paged
      _bookTitle = fileName;
      _bookContent = rawText;
      _pages = pages;
      _currentPage = 1;
      _totalPages = pages.isEmpty ? 1 : pages.length;
      _sliderValue = 0.0;
      _chapterLabel = 'Page 1 / ${pages.length}';
      _isBookLoaded = true;
      _isLoadingBook = false;
    });
    //_fadeController.forward();
  } catch (e) {
    setState(() {
      _isLoadingBook = false;
      _isBookLoaded = false;
    });
    _showMessage('Error loading EPUB: $e');
  }
}

  List<String> _splitIntoPages(String text) {
    const int targetCharsPerPage = 1200;

    final normalized = text.replaceAll('\r\n', '\n');
    final paragraphs = normalized
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return [normalized];

    final List<String> pages = [];
    final StringBuffer buffer = StringBuffer();

    for (final paragraph in paragraphs) {
      final candidate = buffer.isEmpty
          ? paragraph
          : '${buffer.toString()}\n\n$paragraph';

      if (candidate.length <= targetCharsPerPage) {
        buffer
          ..clear()
          ..write(candidate);
      } else {
        if (buffer.isNotEmpty) {
          pages.add(buffer.toString());
          buffer.clear();
        }

        if (paragraph.length <= targetCharsPerPage) {
          buffer.write(paragraph);
        } else {
          int start = 0;
          while (start < paragraph.length) {
            int end = start + targetCharsPerPage;
            if (end >= paragraph.length) {
              pages.add(paragraph.substring(start).trim());
              break;
            }

            int splitAt = paragraph.lastIndexOf(' ', end);
            if (splitAt <= start) splitAt = end;

            pages.add(paragraph.substring(start, splitAt).trim());
            start = splitAt;
          }
        }
      }
    }

    if (buffer.isNotEmpty) pages.add(buffer.toString());

    return pages.isEmpty ? [text] : pages;
  }

  void _previousPage() {
    if (_bookType != 'txt' || !_isBookLoaded || _currentPage <= 1) return;

    setState(() {
      _currentPage--;
      _updateTxtProgress();
    });
  }

/* void _nextPage() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ComprehensionScreen(
        chapterNumber: 1,
        onKeepReading: () => Navigator.of(context).pop(),
      ),
    ),
  );
} */

void _nextPage() {
  if (_bookType != 'txt' || !_isBookLoaded) return;

  if (_currentPage >= 20) {
    // Last page — go to comprehension screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComprehensionScreen(
          chapterNumber: 1,
          onKeepReading: () => Navigator.of(context).pop(),
        ),
      ),
    );
    return;
  }

  setState(() {
    _currentPage++;
    _updateTxtProgress();
  });
}

void _nextChapter() {
  final toc = _epubController?.tableOfContents();
  if (toc == null || toc.isEmpty) return;

  final current = _epubController?.currentValue?.chapter;
  final currentIndex = toc.indexWhere((c) => c.title == current?.Title);

  final targetIndex = (currentIndex + 1).clamp(0, toc.length - 1);
  _epubController?.jumpTo(index: toc[targetIndex].startIndex);
}

void _previousChapter() {
  final toc = _epubController?.tableOfContents();
  if (toc == null || toc.isEmpty) return;

  final current = _epubController?.currentValue?.chapter;
  final currentIndex = toc.indexWhere((c) => c.title == current?.Title);

  final targetIndex = (currentIndex - 1).clamp(0, toc.length - 1);
  _epubController?.jumpTo(index: toc[targetIndex].startIndex);
}

  void _jumpToPage(double value) {
    if (_bookType != 'txt' || !_isBookLoaded || _totalPages <= 1) return;

    final targetPage = ((value * (_totalPages - 1)).round()) + 1;

    setState(() {
      _currentPage = targetPage.clamp(1, _totalPages);
      _updateTxtProgress();
    });
  }

  void _updateTxtProgress() {
    _sliderValue = _totalPages <= 1
        ? 0.0
        : (_currentPage - 1) / (_totalPages - 1);
    _chapterLabel = 'Page $_currentPage / $_totalPages';
  }

  void _showReaderMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import Book'),
              onTap: () {
                Navigator.pop(context);
                _pickAndLoadFile();
              },
            ),
            if (_bookType == 'txt') ...[
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Previous Page'),
                onTap: () {
                  Navigator.pop(context);
                  _previousPage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: const Text('Next Page'),
                onTap: () {
                  Navigator.pop(context);
                  _nextPage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  children: [
                    const ListTile(
                      title: Text(
                        'Reading Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text('Font Size: ${_fontSize.round()}'),
                      subtitle: Slider(
                        min: 14,
                        max: 32,
                        value: _fontSize,
                        onChanged: (value) {
                          setSheetState(() => _fontSize = value);
                          setState(() => _fontSize = value);
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
                        onChanged: (value) {
                          setSheetState(() => _lineHeight = value);
                          setState(() => _lineHeight = value);
                        },
                      ),
                    ),
                    const Divider(),
                    RadioListTile<String>(
                      title: const Text('Paper Theme'),
                      value: 'paper',
                      groupValue: _readerTheme,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => _readerTheme = value);
                        setState(() => _readerTheme = value);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('White Theme'),
                      value: 'white',
                      groupValue: _readerTheme,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => _readerTheme = value);
                        setState(() => _readerTheme = value);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Dark Theme'),
                      value: 'dark',
                      groupValue: _readerTheme,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => _readerTheme = value);
                        setState(() => _readerTheme = value);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.volume_up, color: Colors.white),
              ),
              IconButton(
                onPressed: _showReaderMenu,
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
              IconButton(
                onPressed: _showSettings,
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_bookTitle\n$_chapterLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: Colors.black54,
            ),
            const SizedBox(height: 16),
            const Text(
              'Import a .txt or .epub file to start reading',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'TXT uses the custom reader. EPUB opens in the embedded EPUB view.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickAndLoadFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxtReaderArea() {
    return Container(
      width: double.infinity,
      color: _readerBackgroundColor,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _pages[_currentPage - 1],
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineHeight,
                color: _readerTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpubReaderArea() {
    if (_epubController == null) {
      return const Center(child: Text('EPUB controller not ready.'));
    }

    return Container(
      width: double.infinity,
      color: _readerBackgroundColor,
      child: EpubView(
        controller: _epubController!,
        onDocumentLoaded: (document) {
          if (!mounted) return;
          setState(() {
            _chapterLabel = 'EPUB loaded';
            _sliderValue = 0.0;
          });
        },
        onChapterChanged: (chapter) {
          if (!mounted) return;
          final title = chapter?.chapter?.Title?.trim() ?? '';
          if (title.isNotEmpty) {
            setState(() {
              _chapterLabel = title;
            });
          }
        },
        onDocumentError: (error) {
          _showMessage('EPUB error: $error');
        },
      ),
    );
  }

  Widget _buildReaderArea() {
    if (_isLoadingBook) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isBookLoaded) return _buildEmptyState();

    if (_bookType == 'txt' && _pages.isNotEmpty) {
      return _buildTxtReaderArea();
    }

    if (_bookType == 'epub') {
      return _buildEpubReaderArea();
    }

    return _buildEmptyState();
  }

/*   Widget _buildFooter() {
    ElevatedButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ComprehensionScreen(
              chapterNumber: 1,
              onKeepReading: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
      child: const Text('End Chapter →'),
    );
    final progressText = !_isBookLoaded
        ? 'No progress yet'
        : _bookType == 'txt'
        ? '$_currentPage of $_totalPages'
        : 'EPUB reading mode';

    return Container(
      width: double.infinity,
      color: Colors.grey.shade600,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Text(progressText, style: const TextStyle(color: Colors.white)),
          Slider(
            value: _sliderValue.clamp(0.0, 1.0),
            onChanged: (_bookType == 'txt' && _isBookLoaded)
                ? _jumpToPage
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: (_bookType == 'txt' && _isBookLoaded)
                    ? _previousPage
                    : null,
                child: const Text('Prev'),
              ),
              ElevatedButton.icon(
                onPressed: _pickAndLoadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
              ElevatedButton(
                onPressed: _nextPage,
                child: const Text('next'),
                ),
            ],
          ),
        ],
      ),
    );
  } */

 Widget _buildFooter() {
  if (_bookType == 'epub') {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade600,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Text(
            _chapterLabel,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousChapter,
                child: const Text('Prev Chapter'),
              ),
              ElevatedButton.icon(
                onPressed: _pickAndLoadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
              ElevatedButton(
                onPressed: _nextChapter,
                child: const Text('Next chapter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TXT footer
  return Container(
    width: double.infinity,
    color: Colors.grey.shade600,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Column(
      children: [
        Text(
          '$_currentPage of $_totalPages',
          style: const TextStyle(color: Colors.white),
        ),
        Slider(
          value: _sliderValue.clamp(0.0, 1.0),
          onChanged: (_bookType == 'txt' && _isBookLoaded) ? _jumpToPage : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _previousPage,
              child: const Text('Prev'),
            ),
            ElevatedButton.icon(
              onPressed: _pickAndLoadFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import'),
            ),
            ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _epubController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildReaderArea()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }
}
