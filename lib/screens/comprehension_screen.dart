// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/coin_service.dart';
import 'coins_earned_snack_bar.dart';

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

  static const List<ComprehensionQuestion> _demoQuestions = [
    ComprehensionQuestion(
      question: 'What did the little seed need to grow?',
      answers: ['Water and sunlight', 'Snow and darkness', 'Wind and rocks'],
      correctIndex: 0,
    ),
    ComprehensionQuestion(
      question: 'Where did the story take place?',
      answers: ['In a city', 'In a garden', 'In the ocean'],
      correctIndex: 1,
    ),
  ];

  // Story Sprout brand colours
  static const Color _darkBg = Color(0xFF1A1F1A);
  static const Color _cardBg = Color(0xFF252B25);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _greenDark = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFF5F0E8);
  static const Color _textMuted = Color(0xFF8A9A8A);
  static const Color _correctGreen = Color(0xFF66BB6A);
  static const Color _wrongRed = Color(0xFFEF5350);

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
      // Chapter-specific questions when the caller has them (see
      // QuestionBank), then AI-written ones, otherwise the generic demo pair.
      final generate = widget.generateQuestions;
      final loaded =
          widget.questions ??
          (generate != null ? await generate() : _demoQuestions);
      if (!mounted) return;
      setState(() {
        _questions = loaded;
        _loading = false;
      });
      _fadeController.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Sprout couldn't think of questions right now.";
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

  //answer tile colour
  Color _tileColor(int index) {
    if (!_answered) return _cardBg;
    if (index == _current.correctIndex) return _correctGreen.withOpacity(0.25);
    if (index == _selectedAnswer) return _wrongRed.withOpacity(0.20);
    return _cardBg;
  }

  Color _tileBorderColor(int index) {
    if (!_answered) {
      return index == _selectedAnswer ? _green : Colors.transparent;
    }
    if (index == _current.correctIndex) return _correctGreen;
    if (index == _selectedAnswer) return _wrongRed;
    return Colors.transparent;
  }

  // build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _green),
                  SizedBox(height: 16),
                  Text(
                    'Sprout is thinking of questions…',
                    style: TextStyle(color: _cream, fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
          ? _buildError()
          : _questions.isEmpty
          ? _buildEmpty()
          : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _darkBg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _cream),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.chapterTitle ?? 'End of Chapter ${widget.chapterNumber}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _cream,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        if (widget.skippable)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip', style: TextStyle(color: _cream)),
          ),
      ],
    );
  }

  //  main body
  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 20),
              _buildQuestionBubble(),
              const SizedBox(height: 24),
              ..._buildAnswerTiles(),
              const Spacer(),
              if (_answered) _buildKeepReadingButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // progress dots
  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (i) {
        final active = i == _currentIndex;
        final done = i < _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? _green : _textMuted.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // question bubble
  Widget _buildQuestionBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mascot avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _green.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _green, width: 1.5),
          ),
          child: const Center(
            child: Text('🌱', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        // Question text bubble
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              _current.question,
              style: const TextStyle(color: _cream, fontSize: 15, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  //answer tiles
  List<Widget> _buildAnswerTiles() {
    return List.generate(_current.answers.length, (i) {
      final isCorrect = _answered && i == _current.correctIndex;
      final isWrong =
          _answered && i == _selectedAnswer && i != _current.correctIndex;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: _tileColor(i),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _tileBorderColor(i), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _answered ? null : () => _selectAnswer(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Radio circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCorrect
                              ? _correctGreen
                              : isWrong
                              ? _wrongRed
                              : _textMuted,
                          width: 2,
                        ),
                        color: (isCorrect || isWrong)
                            ? Colors.transparent
                            : Colors.transparent,
                      ),
                      child: isCorrect
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: _correctGreen,
                            )
                          : isWrong
                          ? const Icon(Icons.close, size: 14, color: _wrongRed)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Answer text
                    Expanded(
                      child: Text(
                        _current.answers[i],
                        style: TextStyle(
                          color: isCorrect
                              ? _correctGreen
                              : isWrong
                              ? _wrongRed
                              : _cream,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  //keep reading button
  Widget _buildKeepReadingButton() {
    return ElevatedButton(
      onPressed: _advance,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isLastQuestion ? _greenDark : _cardBg,
        foregroundColor: _cream,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _isLastQuestion ? _green : _textMuted.withOpacity(0.4),
          ),
        ),
        elevation: 0,
      ),
      child: Text(
        _isLastQuestion ? 'Keep Reading →' : 'Next Question →',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  //error / empty states
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _wrongRed, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _cream, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _loadQuestions();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No questions for this chapter yet.',
            style: TextStyle(color: _cream, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Keep Reading →'),
          ),
        ],
      ),
    );
  }
}
