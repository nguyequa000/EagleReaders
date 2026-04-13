import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  SCREEN WIDGET
// ─────────────────────────────────────────────

class ComprehensionScreen extends StatefulWidget {
  /// The chapter number that just finished (e.g. 3)
  final int chapterNumber;

  /// Optional: pass questions in directly (used by tests / story module).
  /// If null the screen loads from assets/data/comprehension_questions.json
  final List<ComprehensionQuestion>? questions;

  /// Called when the user taps "Keep Reading →"
  final VoidCallback? onKeepReading;

  const ComprehensionScreen({
    super.key,
    required this.chapterNumber,
    this.questions,
    this.onKeepReading,
  });

  @override
  State<ComprehensionScreen> createState() => _ComprehensionScreenState();
}

class _ComprehensionScreenState extends State<ComprehensionScreen>
    with SingleTickerProviderStateMixin {
  // ── state ──────────────────────────────────
  List<ComprehensionQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _loading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Story Sprout brand colours ──────────────
  static const Color _darkBg = Color(0xFF1A1F1A);
  static const Color _cardBg = Color(0xFF252B25);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _greenDark = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFF5F0E8);
  static const Color _textMuted = Color(0xFF8A9A8A);
  static const Color _correctGreen = Color(0xFF66BB6A);
  static const Color _wrongRed = Color(0xFFEF5350);

  // ── lifecycle ──────────────────────────────
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

  // ── data loading ───────────────────────────
  Future<void> _loadQuestions() async {
    try {
      List<ComprehensionQuestion> loaded;

      if (widget.questions != null) {
        loaded = widget.questions!;
      } else {
        // Load from bundled JSON asset
        final raw = await rootBundle
            .loadString('assets/data/comprehension_questions.json');
        final List<dynamic> jsonList = jsonDecode(raw);
        loaded = jsonList
            .map((e) => ComprehensionQuestion.fromJson(e))
            .toList();
      }

      setState(() {
        _questions = loaded;
        _loading = false;
      });
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _error = 'Could not load questions.';
        _loading = false;
      });
    }
  }

  // ── helpers ────────────────────────────────
  ComprehensionQuestion get _current => _questions[_currentIndex];

  bool get _isLastQuestion => _currentIndex == _questions.length - 1;

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
    });
  }

  void _advance() {
    if (_isLastQuestion) {
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

  // ── answer tile colour ─────────────────────
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

  // ── build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
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
        'End of Chapter ${widget.chapterNumber}',
        style: const TextStyle(
          color: _cream,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  // ── main body ──────────────────────────────
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

  // ── progress dots ──────────────────────────
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

  // ── question bubble ────────────────────────
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
              style: const TextStyle(
                color: _cream,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── answer tiles ───────────────────────────
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
                    horizontal: 16, vertical: 14),
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
                          ? const Icon(Icons.check,
                              size: 14, color: _correctGreen)
                          : isWrong
                              ? const Icon(Icons.close,
                                  size: 14, color: _wrongRed)
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

  // ── keep reading button ────────────────────
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

  // ── error / empty states ───────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _wrongRed, size: 48),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: _cream, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadQuestions,
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