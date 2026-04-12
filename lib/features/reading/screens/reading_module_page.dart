// Basic reading module page, which will be used to display the reading content.

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_read/flutter_read.dart';

class ReadingModulePage extends StatefulWidget {
  const ReadingModulePage({super.key});

  @override
  State<ReadingModulePage> createState() => _ReadingModulePageState();
}

class _ReadingModulePageState extends State<ReadingModulePage> {
  late final ReadController _readController;
  StreamSubscription<BookProgress>? _progressSubscription;

  int _currentPage = 1;
  int _totalPages = 1;
  double _sliderValue = 0.0;

  String _bookTitle = 'No book selected';
  String _chapterLabel = 'Import a book to begin';

  bool _isBookLoaded = false;
  bool _isLoadingBook = false;

  @override
  void initState() {
    super.initState();

    _readController = ReadController.create(
      loadingWidget: const Center(
        child: CircularProgressIndicator(),
      ),
      enableVerticalDrag: true,
      enableTapPage: true,
    );

    _progressSubscription = _readController.onPageIndexChanged.listen((progress) {
      if (!mounted) return;

      setState(() {
        _currentPage = progress.pageIndex + 1;
        _totalPages = progress.pageTotal <= 0 ? 1 : progress.pageTotal;
        _sliderValue = _totalPages <= 1
            ? 0.0
            : (progress.pageIndex / (_totalPages - 1)).clamp(0.0, 1.0);

        if (progress.chapterTitle.trim().isNotEmpty) {
          _chapterLabel = progress.chapterTitle;
        } else {
          _chapterLabel = 'Page $_currentPage / $_totalPages';
        }
      });
    });
  }

  Future<void> _pickAndLoadFile() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'epub'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final filePath = file.path;
    final fileName = file.name;
    final extension = file.extension?.toLowerCase() ?? '';

    if (filePath == null || filePath.isEmpty) {
      _showErrorDialog('Could not access the selected file path.');
      return;
    }

    if (extension == 'epub') {
      _showErrorDialog(
        'EPUB import is not wired into this screen yet. For now, import a .txt file.',
      );
      return;
    }

    await _loadBookFromFile(filePath, fileName);
  } catch (e) {
    _showErrorDialog('Error picking file: $e');
  }
}

  Future<void> _loadBookFromFile(String filePath, String fileName) async {
    try {
      setState(() {
        _isLoadingBook = true;
      });

      final source = FileSource(
        filePath,
        fileName,
        isSplit: true,
      );

      await _readController.startReadBook(source);

      if (!mounted) return;

      setState(() {
        _bookTitle = fileName;
        _chapterLabel = 'Page 1 / 1';
        _currentPage = 1;
        _totalPages = 1;
        _sliderValue = 0.0;
        _isBookLoaded = true;
        _isLoadingBook = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingBook = false;
      });

      _showErrorDialog('Error loading book: $e');
    }
  }

  void _previousPage() {
    if (!_isBookLoaded) return;
    _readController.previousPage();
  }

  void _nextPage() {
    if (!_isBookLoaded) return;
    _readController.nextPage();
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                const ListTile(
                  title: Text(
                    'Reading Settings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Import Book'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndLoadFile();
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.text_fields),
                  title: Text('Font controls can be added later'),
                ),
                const ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Theme controls can be added later'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReaderMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                onPressed: _showSettingsSheet,
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
              'Import a book to start reading',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'For now, use a .txt file so the reader matches your wireframe cleanly.',
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

  Widget _buildReaderArea() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F5F0),
      child: _isLoadingBook
          ? const Center(child: CircularProgressIndicator())
          : !_isBookLoaded
              ? _buildEmptyState()
              : ReadView(
                  readController: _readController,
                  onMenu: _showReaderMenu,
                  onScroll: () {},
                ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.grey.shade600,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Text(
            _isBookLoaded ? '$_currentPage of $_totalPages' : 'No progress yet',
            style: const TextStyle(color: Colors.white),
          ),
          Slider(
            value: _sliderValue.clamp(0.0, 1.0),
            onChanged: null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _isBookLoaded ? _previousPage : null,
                child: const Text('Prev'),
              ),
              ElevatedButton.icon(
                onPressed: _pickAndLoadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
              ElevatedButton(
                onPressed: _isBookLoaded ? _nextPage : null,
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
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 320,
            height: 640,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildReaderArea()),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


