import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/story_generator.dart';
import 'comprehension_screen.dart';
import 'story/story_button.dart';
import 'story/story_config.dart';
import 'story/story_theme.dart';

/// Reads the story Sprout writes from the child's choices, a chapter at a
/// time: the child picks (or types) what happens next, can have each page
/// read aloud, and answers a short quiz once the story ends.
class StoryReaderScreen extends StatefulWidget {
  final StoryConfig config;

  /// Whose quiz result and coins the end-of-story quiz records. Without one
  /// (the dev entry point) the quiz is skipped.
  final String? childId;
  final String childName;

  /// Turn the last page — opens the screen that asks what to do next.
  ///
  /// Optional: when null, finishing just closes the reader and ordinary back
  /// behaviour is kept.
  final VoidCallback? onNextPage;

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
    this.childId,
    this.childName = '',
    this.onNextPage,
    this.generate,
  });

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
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
  bool _finishing = false;
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
    // No speech engine (tests, some desktops) just means no read-aloud.
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    } catch (_) {}
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

  /// The quiz (when the story ended with one), then whatever comes next.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _tts.stop();
    final story = _story!;
    final childId = widget.childId;
    if (story.questions.isNotEmpty && childId != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ComprehensionScreen(
            childId: childId,
            childName: widget.childName,
            bookTitle: story.title,
            chapterNumber: _chapters,
            questions: story.questions,
          ),
        ),
      );
      if (!mounted) return;
    }
    _finishing = false;
    final next = widget.onNextPage;
    if (next != null) {
      next();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final story = _story;

    // With a page-turn control the reader has replaced the 4-step flow, so
    // there is nothing meaningful behind it to go back to. Blocking pop keeps
    // the hardware back gesture from dropping a child onto a half-built story.
    return PopScope(
      canPop: widget.onNextPage == null || _safetyStop,
      child: Scaffold(
        backgroundColor: palette.ground,
        appBar: AppBar(
          automaticallyImplyLeading: widget.onNextPage == null,
          title: Text(
            'Your Story',
            style: StoryTheme.display(
              size: 19,
              color: palette.headerInk,
              weight: 600,
            ),
          ),
          backgroundColor: palette.header,
          foregroundColor: palette.headerInk,
          elevation: 0,
          actions: [
            if (story != null)
              IconButton(
                tooltip: _speaking ? 'Stop reading' : 'Read aloud',
                icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                onPressed: _toggleSpeech,
              ),
            if (widget.onNextPage != null)
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: "I'm done reading",
                onPressed: () {
                  _tts.stop();
                  widget.onNextPage!();
                },
              ),
          ],
        ),
        body: _safetyStop
            ? _buildSafetyStop(palette)
            : story == null
            ? _buildLoading(palette)
            : _buildBook(palette, story),
      ),
    );
  }

  Widget _buildSafetyStop(StoryPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 48, color: palette.action),
            const SizedBox(height: 16),
            Text(
              "Let's talk to a grown-up about that",
              textAlign: TextAlign.center,
              style: StoryTheme.display(size: 22, color: palette.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Some feelings are big. A grown-up you trust can help.',
              textAlign: TextAlign.center,
              style: StoryTheme.body(color: palette.ink),
            ),
            const SizedBox(height: 16),
            StoryButton(
              label: 'Go back',
              accent: palette.action,
              showArrow: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(StoryPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: palette.action),
          const SizedBox(height: 16),
          Text(
            'Sprout is writing your story…',
            style: StoryTheme.display(size: 18, color: palette.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildBook(StoryPalette palette, Story story) {
    final isLast = _page == story.pages.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailBanner(palette),
          const SizedBox(height: 12),
          if (_offline)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _resting
                          ? "Sprout is resting after lots of stories, so here's a classic! Try again in a minute."
                          : "Sprout couldn't reach the story cloud, so here's a classic!",
                      style: StoryTheme.body(size: 14, color: palette.ink),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          Text(
            story.title,
            textAlign: TextAlign.center,
            style: StoryTheme.display(size: 22, color: palette.ink),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: story.pages.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPageText(palette, story.pages[i], i == _page),
                    if (i == story.pages.length - 1 && !story.ended)
                      _buildChoices(palette, story),
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
                color: palette.ink,
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
                  style: StoryTheme.display(size: 14, color: palette.inkMuted),
                ),
              ),
              isLast && !story.ended
                  ? const SizedBox(width: 48)
                  : isLast
                  ? StoryButton(
                      label: story.questions.isEmpty ? 'The End' : 'Quiz time!',
                      accent: palette.action,
                      onPressed: _finish,
                    )
                  : IconButton(
                      tooltip: 'Next page',
                      icon: const Icon(Icons.arrow_forward_ios),
                      color: palette.ink,
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

  Widget _buildDetailBanner(StoryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        border: Border.all(color: palette.line),
        boxShadow: palette.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'STORY PREVIEW',
            style: StoryTheme.display(
              size: 12,
              color: palette.inkMuted,
              weight: 600,
              tracking: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _bannerLine(palette, 'Hero', widget.config.hero.name ?? 'Your hero'),
          _bannerLine(palette, 'Mood', widget.config.mood),
          _bannerLine(palette, 'Setting', widget.config.setting),
        ],
      ),
    );
  }

  Widget _bannerLine(StoryPalette palette, String caption, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            '$caption: ',
            style: StoryTheme.body(size: 14, color: palette.inkMuted),
          ),
          Text(
            value ?? 'unknown',
            style: StoryTheme.display(
              size: 14,
              color: palette.ink,
              weight: 600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoices(StoryPalette palette, Story story) {
    if (_writing) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            CircularProgressIndicator(color: palette.action),
            const SizedBox(height: 12),
            Text(
              'Sprout is writing what happens next…',
              style: StoryTheme.display(size: 16, color: palette.ink),
            ),
          ],
        ),
      );
    }
    final more = _chapters < _maxChapters;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What happens next?',
            textAlign: TextAlign.center,
            style: StoryTheme.display(size: 20, color: palette.ink),
          ),
          const SizedBox(height: 12),
          if (more)
            for (final choice in story.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StoryButton(
                  label: choice,
                  accent: palette.action,
                  showArrow: false,
                  onPressed: () => _continue(choice),
                ),
              ),
          if (more && !_typingOwn)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StoryButton(
                label: 'I want to write what happens!',
                accent: palette.action,
                showArrow: false,
                filled: false,
                onPressed: () => setState(() => _typingOwn = true),
              ),
            ),
          if (more && _typingOwn) ...[
            TextField(
              controller: _ownIdea,
              autofocus: true,
              maxLength: maxChoiceLength,
              textInputAction: TextInputAction.send,
              onSubmitted: _continueWithOwnIdea,
              onChanged: (_) => setState(() {}),
              style: StoryTheme.body(size: 16, color: palette.ink),
              decoration: InputDecoration(
                hintText: 'What happens next?',
                errorText: hasBadWords(_ownIdea.text) ? badWordsMessage : null,
                filled: true,
                fillColor: palette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Use my idea',
                  icon: Icon(Icons.send, color: palette.ink),
                  onPressed: () => _continueWithOwnIdea(_ownIdea.text),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          OutlinedButton(
            onPressed: () => _continue(null),
            style: OutlinedButton.styleFrom(foregroundColor: palette.ink),
            child: const Text('Finish the story'),
          ),
        ],
      ),
    );
  }

  // Highlights the word TTS is currently speaking on the visible page.
  Widget _buildPageText(StoryPalette palette, String text, bool current) {
    final style = StoryTheme.body(size: 22, color: palette.ink, height: 1.6);
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
            style: const TextStyle(
              backgroundColor: _highlight,
              color: Color(0xFF2E2E2E),
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
