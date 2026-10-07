import 'package:flutter/material.dart';
import 'ai_story_screen.dart';
import 'child_rewards_screen.dart';
import 'reading_library_screen.dart';
import 'story_character_screen.dart';
import 'story_flow_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childName;

  const ChildDashboardScreen({super.key, required this.childName});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  int _selectedTab = 0;

  // DEMO data
  final List<Map<String, String>> _continueReading = [
    {'title': 'The Tiny Seed', 'emoji': '🌱'},
    {'title': 'Paddington Bear', 'emoji': '🐻'},
    {'title': 'The Very Hungry Caterpillar', 'emoji': '🐛'},
    {'title': 'Charlotte\'s Web', 'emoji': '🕷️'},
  ];

  // Ready-made story ideas; tapping one writes a fresh story from it.
  static const _storyPresets = [
    (
      title: 'Dragon Adventure',
      emoji: '🐉',
      config: StoryConfig(
        character: 'Friendly Dragon',
        mood: 'Adventurous',
        setting: 'Forest',
        idea: 'The dragon goes looking for a lost treasure.',
      ),
    ),
    (
      title: 'Space Explorer',
      emoji: '🚀',
      config: StoryConfig(
        character: 'Clever Fox',
        mood: 'Adventurous',
        setting: 'Outer Space',
        idea: 'The fox flies a rocket to visit a new planet.',
      ),
    ),
    (
      title: 'Magic Forest',
      emoji: '🌲',
      config: StoryConfig(
        character: 'Magic Fairy',
        mood: 'Calm',
        setting: 'Forest',
        idea: 'The fairy helps the forest animals get ready for winter.',
      ),
    ),
    (
      title: 'Ocean Quest',
      emoji: '🌊',
      config: StoryConfig(
        character: 'Brave Knight',
        mood: 'Funny',
        setting: 'Ocean',
        idea: 'The knight sails to find a singing sea turtle.',
      ),
    ),
  ];

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openLibrary() =>
      _push(ReadingLibraryScreen(childName: widget.childName));

  void _createStory() => _push(StoryFlowScreen(childName: widget.childName));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Hi ${widget.childName}! 🌱'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.redeem),
            tooltip: 'My Rewards',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChildRewardsScreen(childName: widget.childName),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [_buildHomeTab(), _buildReadTab(), _buildMyStoriesTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          if (index == 1) return _openLibrary();
          if (index == 2) return _createStory();
          setState(() => _selectedTab = index);
        },
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Read a Story',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Create a Story',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Continue Reading'),
          const SizedBox(height: 12),
          _buildBookGrid([
            for (final book in _continueReading)
              _BookCard(
                title: book['title']!,
                emoji: book['emoji']!,
                onTap: _openLibrary,
              ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('My Stories'),
          const SizedBox(height: 12),
          _buildBookGrid([
            for (final preset in _storyPresets)
              _BookCard(
                title: preset.title,
                emoji: preset.emoji,
                onTap: () => _push(
                  StoryReaderScreen(
                    config: preset.config,
                    childName: widget.childName,
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(thickness: 1.5, color: Colors.black26)),
      ],
    );
  }

  Widget _buildBookGrid(List<Widget> cards) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: cards,
    );
  }

  // Placeholder tabs — bottom nav navigates away for read/create
  Widget _buildReadTab() => const SizedBox.shrink();
  Widget _buildMyStoriesTab() => const SizedBox.shrink();
}

class _BookCard extends StatelessWidget {
  final String title;
  final String emoji;
  final VoidCallback onTap;

  const _BookCard({
    required this.title,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 48)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
