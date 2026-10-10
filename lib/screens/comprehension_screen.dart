import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/coin_service.dart';
import '../services/story_generator.dart' show isQuotaError;
import 'coins_earned_snack_bar.dart';
import 'sticker_kit.dart';
import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_sprout_bubble.dart';
import 'story/story_theme.dart';

// Data model
class ComprehensionQuestion {
  final String question;
  final List<String> answers;
  final int correctIndex;

  const ComprehensionQuestion({
    required this.question,
    required this.answers,
    required this.correctIndex,
  });

  factory ComprehensionQuestion.fromJson(Map<String, dynamic> json) {
    return ComprehensionQuestion(
      question: json['question'] as String,
      answers: List<String>.from(json['answers']),
      correctIndex: json['correct'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'answers': answers,
    'correct': correctIndex,
  };
}

//  Screen widget
class ComprehensionScreen extends StatefulWidget {
  /// Whose activity log the result is recorded against.
  final String childId;
  final String childName;
  final String bookTitle;

  /// The chapter number that just finished (e.g. 3)
  final int chapterNumber;

  /// Questions to ask directly (story module, tests).
  final List<ComprehensionQuestion>? questions;

  /// Writes the questions when [questions] is null (e.g. the local model).
  final Future<List<ComprehensionQuestion>> Function()? generateQuestions;

  /// Called when the user taps "Keep Reading →"
  final VoidCallback? onKeepReading;

  /// The chapter's own title (e.g. "CHAPTER I. Down the Rabbit-Hole"), shown
  /// instead of "End of Chapter N" when the book provides one.
  final String? chapterTitle;

  /// Shows a Skip button that closes the quiz without recording a score
  /// (used for the quizzes that pop up at the end of each chapter).
  final bool skippable;

  const ComprehensionScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.bookTitle,
    required this.chapterNumber,
    this.questions,
    this.generateQuestions,
    this.onKeepReading,
    this.chapterTitle,
    this.skippable = false,
  });

  @override
  State<ComprehensionScreen> createState() => _ComprehensionScreenState();
}

class _ComprehensionScreenState extends State<ComprehensionScreen>
    with SingleTickerProviderStateMixin {
  // state
  List<ComprehensionQuestion> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _savingResult = false;
  int? _selectedAnswer;
  bool _answered = false;
  bool _loading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // lifecycle
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadQuestions();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // data loading
  Future<void> _loadQuestions() async {
    try {
      // Questions the caller already has (a story's own quiz), otherwise the
      // ones Gemini writes for this book or chapter.
      final generate = widget.generateQuestions;
      final loaded =
          widget.questions ?? (generate != null ? await generate() : []);
      if (!mounted) return;
      setState(() {
        _questions = loaded;
        _loading = false;
      });
      _fadeController.forward();
    } catch (e) {
      debugPrint('Quiz questions failed: $e');
      if (!mounted) return;
      setState(() {
        _error = isQuotaError(e)
            ? 'Sprout needs a short rest. Try again in a minute!'
            : "Sprout couldn't think of questions right now.";
        _loading = false;
      });
    }
  }

  // helpers
  ComprehensionQuestion get _current => _questions[_currentIndex];

  bool get _isLastQuestion => _currentIndex == _questions.length - 1;

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (index == _current.correctIndex) _correctCount++;
    });
  }

  Future<void> _advance() async {
    if (!_answered || _savingResult) return;
    if (_isLastQuestion) {
      _savingResult = true;
      try {
        await ActivityService.instance.logEvent(
          widget.childId,
          'comprehension_result',
          {
            'title': widget.bookTitle,
            'chapter': widget.chapterNumber,
            if (widget.chapterTitle != null)
              'chapterTitle': widget.chapterTitle,
            // Kept for backwards-compat with any older readers of this log.
            'score': '$_correctCount/${_questions.length}',
            'correct': _correctCount,
            'total': _questions.length,
          },
        );
      } finally {
        _savingResult = false;
      }
      if (!mounted) return;
      await _awardCoins();
      if (!mounted) return;
      widget.onKeepReading?.call();
      if (widget.onKeepReading == null) Navigator.of(context).pop();
    } else {
      _fadeController.reset();
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      _fadeController.forward();
    }
  }

  /// Coins for finishing the quiz (CR #2). A failed award must never stop the
  /// child getting back to the book, so errors are swallowed.
  Future<void> _awardCoins() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final coins = await CoinService.instance.awardQuiz(
        widget.childId,
        widget.bookTitle,
      );
      if (coins > 0) messenger?.showSnackBar(coinsEarnedSnackBar(coins));
    } catch (_) {}
  }

  // build
  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      body: PaperBackground(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? _buildLoading(palette)
                  : _error != null
                  ? _buildMessage(
                      palette,
                      _error!,
                      retry: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                        });
                        _loadQuestions();
                      },
                    )
                  : _questions.isEmpty
                  ? _buildMessage(palette, 'No questions for this chapter yet.')
                  : _buildBody(palette),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final palette = StoryTheme.of(context);
    return StickerHeader(
      title: widget.chapterTitle ?? 'End of Chapter ${widget.chapterNumber}',
      showBack: true,
      onBack: () => Navigator.of(context).pop(),
      trailing: [
        if (widget.skippable)
          StickerPill(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Skip',
              style: StoryTheme.display(
                size: 15,
                color: palette.ink,
                weight: 700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoading(StoryPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sproutSticker(palette),
          const SizedBox(height: 20),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: palette.action,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sprout is thinking of questions…',
            style: StoryTheme.display(
              size: 17,
              color: palette.ink,
              weight: 600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sproutSticker(StoryPalette palette) {
    return Transform.rotate(
      angle: stickerTilt(0),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: palette.tintGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
          boxShadow: palette.cardShadow(),
        ),
        child: const Center(child: Text('🌱', style: TextStyle(fontSize: 42))),
      ),
    );
  }

  //  main body
  /// The question and answers scroll; the button stays pinned under them,
  /// like the story steps, so a long answer list never pushes it out of reach.
  Widget _buildBody(StoryPalette palette) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                // Bottom room for the last tile's hard shadow.
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgressIndicator(palette),
                    const SizedBox(height: 20),
                    StorySproutBubble(
                      message: _current.question,
                      accent: palette.action,
                    ),
                    const SizedBox(height: 24),
                    ..._buildAnswerTiles(palette),
                  ],
                ),
              ),
            ),
            // Laid out before an answer too (just hidden), so the tiles
            // don't shift up and down as the button comes and goes.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Visibility(
                visible: _answered,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _buildKeepReadingButton(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chunky beads, one per question, like the story steps' progress bar.
  Widget _buildProgressIndicator(StoryPalette palette) {
    return Column(
      children: [
        Text(
          'QUESTION ${_currentIndex + 1} OF ${_questions.length}',
          style: StoryTheme.display(
            size: 12,
            color: palette.inkMuted,
            weight: 700,
            tracking: 1.6,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: List.generate(_questions.length, (i) {
            final done = i < _currentIndex || (i == _currentIndex && _answered);
            return Expanded(
              child: Container(
                height: 11,
                margin: EdgeInsets.only(
                  right: i < _questions.length - 1 ? 7 : 0,
                ),
                decoration: BoxDecoration(
                  color: done ? palette.action : palette.track,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: palette.outline,
                    width: StoryTheme.outlineWidthThin,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Each answer is a tinted sticker, tipped like the story tiles. Once one
  /// is picked, the right answer turns green with a tick, a wrong pick turns
  /// coral with a cross, and the rest fade back so the result stands out.
  List<Widget> _buildAnswerTiles(StoryPalette palette) {
    return List.generate(_current.answers.length, (i) {
      final isCorrect = _answered && i == _current.correctIndex;
      final isWrong =
          _answered && i == _selectedAnswer && i != _current.correctIndex;

      final Color fill;
      if (isCorrect) {
        fill = palette.tintGreen;
      } else if (isWrong) {
        fill = palette.tintCoral;
      } else if (_answered) {
        fill = palette.surface;
      } else {
        fill = palette.tintForIndex(i);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: StickerCard(
          // Keyed by question too, so a tile held down as the question
          // changed doesn't carry its pressed state onto the next one.
          key: ValueKey('answer-$_currentIndex-$i'),
          color: fill,
          tilt: stickerTilt(i),
          radius: StoryTheme.radiusButton,
          selected: _selectedAnswer == i,
          onTap: _answered ? null : () => _selectAnswer(i),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              _answerBadge(palette, i, isCorrect: isCorrect, isWrong: isWrong),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _current.answers[i],
                  style: StoryTheme.body(
                    size: 16,
                    color: _answered && !isCorrect && !isWrong
                        ? palette.inkMuted
                        : palette.ink,
                    weight: 700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// A round sticker with the answer's letter, or a tick or cross once the
  /// question is answered.
  Widget _answerBadge(
    StoryPalette palette,
    int i, {
    required bool isCorrect,
    required bool isWrong,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: palette.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidthThin,
        ),
      ),
      child: Center(
        child: isCorrect
            ? Icon(Icons.check, size: 18, color: palette.ink)
            : isWrong
            ? Icon(Icons.close, size: 18, color: palette.ink)
            : Text(
                String.fromCharCode(0x41 + i),
                style: StoryTheme.display(
                  size: 15,
                  color: palette.ink,
                  weight: 700,
                ),
              ),
      ),
    );
  }

  //keep reading button
  Widget _buildKeepReadingButton(StoryPalette palette) {
    return StoryButton(
      label: _isLastQuestion ? 'Keep Reading →' : 'Next Question →',
      accent: palette.action,
      showArrow: false,
      onPressed: _answered ? _advance : null,
    );
  }

  //error / empty states
  /// Sprout saying what went wrong, with a way back to the book — no quiz
  /// shouldn't mean no way back. [retry] adds a Retry button above it.
  Widget _buildMessage(
    StoryPalette palette,
    String message, {
    VoidCallback? retry,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StorySproutBubble(message: message, accent: palette.action),
            const SizedBox(height: 24),
            if (retry != null) ...[
              StoryButton(
                label: 'Retry',
                accent: palette.action,
                showArrow: false,
                onPressed: retry,
              ),
              const SizedBox(height: 14),
            ],
            StoryButton(
              label: 'Keep Reading →',
              accent: palette.action,
              filled: retry == null,
              showArrow: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
