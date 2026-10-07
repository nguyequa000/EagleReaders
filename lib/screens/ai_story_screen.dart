import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/activity_service.dart';
import '../services/story_generator.dart';
import 'comprehension_screen.dart';
import 'story_character_screen.dart';

class StoryReaderScreen extends StatefulWidget {
  final StoryConfig config;
  final String childName;

  /// Defaults to [generateStory]; tests pass a fake.
  final Future<Story> Function(
    StoryConfig config, {
    Story? soFar,
    String? choice,
  })?
  generate;

  const StoryReaderScreen({
    super.key,
    required this.config,
    required this.childName,
    this.generate,
  });

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  static const Color _forestGreen = Color(0xFF3D6B1A);
  static const Color _cream = Color(0xFFF5F0DC);
  static const Color _highlight = Color(0xFFFFE08A);
  static const _timeout = Duration(seconds: 60);
  // Keeps the prompt (which carries the whole story so far) small.
  static const _maxChapters = 5;

  final FlutterTts _tts = FlutterTts();
  final PageController _pageController = PageController();
  final _ownIdea = TextEditingController();
  bool _typingOwn = false;

  Story? _story;
  bool _offline = false;
  bool _resting = false;
  bool _safetyStop = false;
  int _chapters = 1;
  bool _writing = false;
  int _page = 0;
  bool _speaking = false;
  int? _wordStart;
  int? _wordEnd;

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    _ownIdea.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ]);
    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      setState(() {
        _wordStart = start;
        _wordEnd = end;
      });
    });
    _tts.setCompletionHandler(_clearSpeech);
    _tts.setCancelHandler(_clearSpeech);
  }

  void _clearSpeech() {
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _wordStart = _wordEnd = null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _story = null;
      _page = 0;
      _chapters = 1;
    });
    Story story;
    var offline = false;
    var resting = false;
    try {
      story = await (widget.generate ?? generateStory)(
        widget.config,
      ).timeout(_timeout);
    } on SafetyStopException {
      if (mounted) setState(() => _safetyStop = true);
      return;
    } catch (e) {
      debugPrint('Story generation failed, using fallback: $e');
      story = fallbackStory(widget.config);
      offline = true;
      resting = isQuotaError(e);
    }
    if (!mounted) return;
    setState(() {
      _story = story;
      _offline = offline;
      _resting = resting;
    });
    if (!offline) {
      await ActivityService.instance
          .logEvent(widget.childName, 'story_created', {
            'title': story.title,
            'character': widget.config.character,
            'mood': widget.config.mood,
            'setting': widget.config.setting,
          });
    }
  }

  // Writes the next chapter from the child's [choice], or the ending when null.
  Future<void> _continue(String? choice) async {
    final story = _story!;
    if (_writing) return;
    _tts.stop();
    setState(() => _writing = true);
    try {
      final chapter = await (widget.generate ?? generateStory)(
        widget.config,
        soFar: story,
        choice: choice,
      ).timeout(_timeout);
      if (!mounted) return;
      setState(() {
        _story = story.continuedWith(chapter);
        _chapters++;
        _ownIdea.clear();
        _typingOwn = false;
      });
      // Wait for the PageView to know about the new pages before turning.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } on SafetyStopException {
      if (mounted) setState(() => _safetyStop = true);
    } catch (e) {
      debugPrint('Next chapter failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isQuotaError(e)
                  ? 'Sprout needs a short rest. Try again in a minute!'
                  : "Sprout couldn't write that part. Try again!",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _continueWithOwnIdea(String idea) {
    if (hasBadWords(idea)) return; // the field already shows why
    if (idea.trim().isNotEmpty) _continue(idea.trim());
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _tts.stop();
      _clearSpeech();
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(_story!.pages[_page]);
  }

  void _onPageChanged(int page) {
    _tts.stop();
    setState(() {
      _page = page;
      _speaking = false;
      _wordStart = _wordEnd = null;
    });
  }

  void _finish() {
    _tts.stop();
    final story = _story!;
    // `true` tells StoryFlowScreen the story is done, so it closes too.
    if (story.questions.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacement(
      result: true,
      MaterialPageRoute(
        builder: (_) => ComprehensionScreen(
          childName: widget.childName,
          bookTitle: story.title,
          chapterNumber: _chapters,
          questions: story.questions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    return Scaffold(
      appBar: AppBar(
        title: Text(story?.title ?? 'Your Story'),
        backgroundColor: _forestGreen,
        foregroundColor: Colors.white,
        actions: [
          if (story != null)
            IconButton(
              tooltip: _speaking ? 'Stop reading' : 'Read aloud',
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
              onPressed: _toggleSpeech,
            ),
        ],
      ),
      backgroundColor: _cream,
      body: _safetyStop
          ? _buildSafetyStop()
          : story == null
          ? _buildLoading()
          : _buildBook(story),
    );
  }

  Widget _buildSafetyStop() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 48, color: _forestGreen),
            const SizedBox(height: 16),
            const Text(
              "Let's talk to a grown-up about that",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: _forestGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Some feelings are big. A grown-up you trust can help.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _forestGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _forestGreen),
          SizedBox(height: 16),
          Text(
            'Sprout is writing your story…',
            style: TextStyle(fontSize: 18, color: _forestGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildBook(Story story) {
    final isLast = _page == story.pages.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_offline)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _resting
                          ? "Sprout is resting after lots of stories, so here's a classic! Try again in a minute."
                          : "Sprout couldn't reach the story cloud, so here's a classic!",
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: story.pages.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPageText(story.pages[i], i == _page),
                    if (i == story.pages.length - 1 && !story.ended)
                      _buildChoices(story),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _page == 0
                    ? null
                    : () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
              ),
              Expanded(
                child: Text(
                  'Page ${_page + 1} of ${story.pages.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _forestGreen),
                ),
              ),
              isLast && !story.ended
                  ? const SizedBox(width: 48)
                  : isLast
                  ? ElevatedButton(
                      onPressed: _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _forestGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        story.questions.isEmpty ? 'The End' : 'Quiz time!',
                      ),
                    )
                  : IconButton(
                      tooltip: 'Next page',
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoices(Story story) {
    if (_writing) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Column(
          children: [
            CircularProgressIndicator(color: _forestGreen),
            SizedBox(height: 12),
            Text(
              'Sprout is writing what happens next…',
              style: TextStyle(fontSize: 16, color: _forestGreen),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What happens next?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _forestGreen,
            ),
          ),
          const SizedBox(height: 12),
          if (_chapters < _maxChapters)
            for (final choice in story.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: () => _continue(choice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _forestGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    choice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          if (_chapters < _maxChapters && !_typingOwn)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _typingOwn = true),
                icon: const Icon(Icons.edit),
                label: const Text(
                  'I want to write what happens!',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (_chapters < _maxChapters && _typingOwn) ...[
            TextField(
              controller: _ownIdea,
              autofocus: true,
              maxLength: maxChoiceLength,
              textInputAction: TextInputAction.send,
              onSubmitted: _continueWithOwnIdea,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'What happens next?',
                errorText: hasBadWords(_ownIdea.text) ? badWordsMessage : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Use my idea',
                  icon: const Icon(Icons.send, color: _forestGreen),
                  onPressed: () => _continueWithOwnIdea(_ownIdea.text),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          OutlinedButton(
            onPressed: () => _continue(null),
            style: OutlinedButton.styleFrom(foregroundColor: _forestGreen),
            child: const Text('Finish the story'),
          ),
        ],
      ),
    );
  }

  // Highlights the word TTS is currently speaking on the visible page.
  Widget _buildPageText(String text, bool current) {
    const style = TextStyle(
      fontSize: 22,
      height: 1.6,
      color: Color(0xFF2E2E2E),
    );
    final start = _wordStart, end = _wordEnd;
    if (!current ||
        start == null ||
        end == null ||
        end > text.length ||
        start >= end) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(backgroundColor: _highlight),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
