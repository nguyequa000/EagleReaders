import 'package:flutter/material.dart';

// Carries the user's story choices across all 4 steps
class StoryConfig {
  final String? character;
  final String? mood;
  final String? setting;

  const StoryConfig({this.character, this.mood, this.setting});

  StoryConfig copyWith({String? character, String? mood, String? setting}) {
    return StoryConfig(
      character: character ?? this.character,
      mood: mood ?? this.mood,
      setting: setting ?? this.setting,
    );
  }
}

class _CharacterOption {
  final String label;
  final String emoji;

  const _CharacterOption(this.label, this.emoji);
}

// Step 1 of 4 in the AI story creation flow — character selection
class StoryCharacterScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(StoryConfig config)? onNext;

  const StoryCharacterScreen({super.key, this.onBack, this.onNext});

  @override
  State<StoryCharacterScreen> createState() => _StoryCharacterScreenState();
}

class _StoryCharacterScreenState extends State<StoryCharacterScreen> {
  // Theme colors 
  static const Color _forestGreen = Color(0xFF3D6B1A);
  static const Color _buttonGreen = Color(0xFF4A7C20);
  static const Color _cream = Color(0xFFF5F0DC);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _sectionLabel = Color(0xFF5C7A2A);
  static const Color _selectedBg = Color(0xFFE8F5D0);

  // Placeholder characters — replace with real data later
  static const List<_CharacterOption> _characters = [
    _CharacterOption('Brave Knight', '⚔️'),
    _CharacterOption('Friendly Dragon', '🐉'),
    _CharacterOption('Clever Fox', '🦊'),
    _CharacterOption('Magic Fairy', '🧚'),
  ];

  String? _selected;

  // Passes the chosen character to the next step
  void _handleNext() {
    if (_selected == null) return;
    widget.onNext?.call(StoryConfig(character: _selected));
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
                  _buildSectionLabel('CHOOSE YOUR CHARACTER'),
                  const SizedBox(height: 12),
                  // Grid expands to fill remaining space so nothing scrolls
                  Expanded(child: _buildCharacterGrid()),
                  const SizedBox(height: 12),
                  // Next button only appears once a character is selected
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
      // Top padding accounts for the device status bar
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
          // Spacer keeps the title visually centered under the back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // Reusable uppercase section heading used across story steps
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

  // Sprout mascot speech bubble prompting the child to pick a character
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
          // Sprout avatar
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
              "Hi! I'm Sprout! I'll help you write your story. First — who is your story about?",
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

  Widget _buildCharacterGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: false,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: _characters.map((c) => _buildCharacterTile(c)).toList(),
    );
  }

  // Individual selectable character card
  Widget _buildCharacterTile(_CharacterOption character) {
    final isSelected = _selected == character.label;

    return GestureDetector(
      onTap: () => setState(() => _selected = character.label),
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
                  character.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              character.label,
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

  // Shows which step of 4 the user is on
  Widget _buildProgressBar() {
    return Container(
      color: _forestGreen,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          const Text(
            '1 of 4',
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
                    color: i == 0
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
