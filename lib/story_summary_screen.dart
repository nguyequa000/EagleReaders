import 'package:flutter/material.dart';
import 'story_character_screen.dart';

class StorySummaryScreen extends StatelessWidget {
  final StoryConfig config;
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onStartReading;

  const StorySummaryScreen({super.key, required this.config, this.onBack, this.onStartReading});

  static const Color _forestGreen = Color(0xFF3D6B1A);
  static const Color _buttonGreen = Color(0xFF4A7C20);
  static const Color _cream = Color(0xFFF5F0DC);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _sectionLabel = Color(0xFF5C7A2A);
  static const Color _selectedBg = Color(0xFFE8F5D0);

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
                  const SizedBox(height: 24),
                  _buildSectionLabel('YOUR STORY'),
                  const SizedBox(height: 12),
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  _buildStartReadingButton(),
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
            onPressed: onBack ?? () => Navigator.of(context).pop(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _sectionLabel,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFFCCCCCC), thickness: 1, height: 1),
      ],
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
              "Here is your story so far — ready to start reading?",
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

  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Character', config.character ?? '—', '⚔️'),
          _buildDivider(),
          _buildSummaryRow('Mood', config.mood ?? '—', '😄'),
          _buildDivider(),
          _buildSummaryRow('Setting', config.setting ?? '—', '🌲'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF0EDE0),
    );
  }

  Widget _buildSummaryRow(String label, String value, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3B3B3B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _buttonGreen, width: 1),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartReadingButton() {
    return ElevatedButton(
      onPressed: () => onStartReading?.call(config),
      style: ElevatedButton.styleFrom(
        backgroundColor: _buttonGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: const Text(
        'Start Reading!',
        style: TextStyle(
          fontSize: 17,
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
            '4 of 4',
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
                    color: Colors.white,
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
