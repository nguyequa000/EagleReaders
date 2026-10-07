import 'package:flutter/material.dart';
import '../services/coin_service.dart';
import 'ai_story_screen.dart';
import 'child_rewards_screen.dart';
import 'reading_library_screen.dart';
import 'story/hero_config.dart';
import 'story/story_config.dart';
import 'story_flow_screen.dart';
import 'live_refresh.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildDashboardScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with LiveRefresh {
  int _selectedTab = 0;
  int? _coins;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    // Coins a parent gives back, or a redemption decided on their phone.
    refreshOn(
      () => [CoinService.instance.changes(widget.childId)],
      _loadBalance,
    );
  }

  /// Re-read after every pushed screen returns: quizzes and stories earn
  /// coins, and redeeming spends them.
  Future<void> _loadBalance() async {
    int coins;
    try {
      coins = await CoinService.instance.balance(widget.childId);
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _coins = coins);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _loadBalance();
  }

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
        hero: HeroConfig(character: 'monster'),
        mood: 'Adventurous',
        setting: 'Forest',
        idea: 'A friendly dragon goes looking for a lost treasure.',
      ),
    ),
    (
      title: 'Space Explorer',
      emoji: '🚀',
      config: StoryConfig(
        hero: HeroConfig(character: 'explorer'),
        mood: 'Adventurous',
        setting: 'Outer Space',
        idea: 'The explorer flies a rocket to visit a new planet.',
      ),
    ),
    (
      title: 'Magic Forest',
      emoji: '🌲',
      config: StoryConfig(
        hero: HeroConfig(character: 'friend'),
        mood: 'Calm',
        setting: 'Forest',
        idea: 'Helping the forest animals get ready for winter.',
      ),
    ),
    (
      title: 'Ocean Quest',
      emoji: '🌊',
      config: StoryConfig(
        hero: HeroConfig(character: 'scout'),
        mood: 'Funny',
        setting: 'Ocean',
        idea: 'Sailing off to find a singing sea turtle.',
      ),
    ),
  ];

  void _openLibrary() => _push(
    ReadingLibraryScreen(childId: widget.childId, childName: widget.childName),
  );

  void _createStory() => _push(
    StoryFlowScreen(childId: widget.childId, childName: widget.childName),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Hi ${widget.childName}! 🌱'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          if (_coins != null)
            _CoinChip(
              coins: _coins!,
              onTap: () => _push(
                ChildRewardsScreen(
                  childId: widget.childId,
                  childName: widget.childName,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.redeem),
            tooltip: 'My Rewards',
            onPressed: () => _push(
              ChildRewardsScreen(
                childId: widget.childId,
                childName: widget.childName,
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
                    childId: widget.childId,
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

/// The child's coin balance in the app bar; tapping it opens My Rewards.
class _CoinChip extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;

  const _CoinChip({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '🪙 $coins',
                key: const Key('coinBalance'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
