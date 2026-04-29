import 'package:flutter/material.dart';
import 'story_character_screen.dart';

class _MoodOption {
  final String label;
  final String emoji;

  const _MoodOption(this.label, this.emoji);
}

class StoryMoodScreen extends StatefulWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  const StoryMoodScreen({super.key, required this.config, this.onBack, this.onNext});

  @override
  State<StoryMoodScreen> createState() => _StoryMoodScreenState();
}

class _StoryMoodScreenState extends State<StoryMoodScreen> {
  static const Color _forestGreen = Color(0xFF3D6B1A);
  static const Color _buttonGreen = Color(0xFF4A7C20);
  static const Color _cream = Color(0xFFF5F0DC);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _sectionLabel = Color(0xFF5C7A2A);
  static const Color _selectedBg = Color(0xFFE8F5D0);

  static const List<_MoodOption> _moods = [
    _MoodOption('Funny', '😄'),
    _MoodOption('Adventurous', '🏕️'),
    _MoodOption('Spooky', '👻'),
    _MoodOption('Calm', '😌'),
  ];

  String? _selected;

  void _handleNext() {
    if (_selected == null) return;
    widget.onNext?.call(widget.config.copyWith(mood: _selected));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSproutBubble(),
                  const SizedBox(height: 16),
                  _buildSectionLabel('CHOOSE A MOOD'),
                  const SizedBox(height: 12),
                  Expanded(child: _buildMoodGrid()),
                  const SizedBox(height: 12),
                  if (_selected != null) _buildNextButton(),
                  if (_selected != null) const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _forestGreen,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 4,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              "Let's Build Something!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _sectionLabel,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildSproutBubble() {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _selectedBg,
              shape: BoxShape.circle,
              border: Border.all(color: _buttonGreen, width: 1.5),
            ),
            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Great choice! Now, what kind of mood should your story have?",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B3B3B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: false,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: _moods.map((m) => _buildMoodTile(m)).toList(),
    );
  }

  Widget _buildMoodTile(_MoodOption mood) {
    final isSelected = _selected == mood.label;

    return GestureDetector(
      onTap: () => setState(() => _selected = mood.label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? _selectedBg : _cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _buttonGreen : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.12 : 0.06),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _selectedBg,
                shape: BoxShape.circle,
                border: Border.all(color: _buttonGreen, width: 1.5),
              ),
              child: Center(
                child: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mood.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? _forestGreen : const Color(0xFF3B3B3B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return ElevatedButton(
      onPressed: _handleNext,
      style: ElevatedButton.styleFrom(
        backgroundColor: _buttonGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: const Text(
        'Next →',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: _forestGreen,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          const Text(
            '2 of 4',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i == 1
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
