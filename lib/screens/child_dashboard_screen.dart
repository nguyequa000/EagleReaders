import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/book_library.dart';
import '../services/coin_service.dart';
import '../services/family_settings.dart';
import '../services/reader_audience.dart';
import '../services/story_generator.dart';
import '../services/story_store.dart';
import 'ai_story_screen.dart';
import 'book_cover.dart';
import 'child_rewards_screen.dart';
import 'reading_library_screen.dart';
import 'story/hero_config.dart';
import 'story/story_config.dart';
import 'story_flow_screen.dart';
import 'live_refresh.dart';
import 'comprehension_screen.dart';
import 'my_story_screen.dart';
import 'story_saving.dart';
import 'story_writer_screen.dart';
import 'parent_pin_screen.dart';
import 'reading_module_page.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  final String childName;

  /// The child's shelf; defaults to their [BookLibrary] on this device.
  final BookLibrary? library;

  const ChildDashboardScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.library,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with LiveRefresh {
  int _selectedTab = 0;
  int? _coins;

  late final BookLibrary _library =
      widget.library ?? BookLibrary(widget.childId);

  /// The child's books, most recently opened (or added) first. Null until
  /// loaded.
  List<Book>? _books;

  /// How many books the home tab shows before "See all".
  static const _homeBooks = 4;

  /// The child's saved stories (written by them or with Sprout), most
  /// recently changed first. Null until loaded.
  List<StoredStory>? _stories;

  /// Parent Settings, and this child's age band and daily limit.
  AiSettings _ai = const AiSettings();
  ChildRules _rules = const ChildRules();
  int _minutesToday = 0;

  /// Assumed until the activity loads, so no reminder flashes up first.
  bool _readToday = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Coins a parent gives back, a redemption decided on their phone, or a
    // setting changed in Parent Settings.
    refreshOn(
      () => [
        CoinService.instance.changes(widget.childId),
        FamilySettings.instance.changes(childId: widget.childId),
        StoryStore.instance.changes(widget.childId),
      ],
      _refresh,
    );
  }

  Future<void> _refresh() =>
      Future.wait([_loadBalance(), _loadRules(), _loadBooks(), _loadStories()]);

  Future<void> _loadStories() async {
    List<StoredStory> stories;
    try {
      stories = await StoryStore.instance.loadStories(widget.childId);
    } catch (_) {
      stories = const [];
    }
    if (mounted) setState(() => _stories = stories);
  }

  /// A finished story, to read again.
  void _readStory(StoredStory story) =>
      _push(MyStoryScreen(title: story.title, text: story.text));

  /// An unfinished story, back where the child left it.
  Future<void> _resumeStory(StoredStory story) async {
    if (_locked) return _showDoneForToday();
    if (story.byAi) {
      final questions = <ComprehensionQuestion>[];
      for (final q in story.questions) {
        try {
          questions.add(ComprehensionQuestion.fromJson(q));
        } catch (_) {}
      }
      return _push(
        StoryReaderScreen(
          config: story.config,
          childId: widget.childId,
          childName: widget.childName,
          initialStory: Story(
            title: story.title,
            pages: story.pages,
            choices: story.choices,
            questions: questions,
          ),
          initialPage: story.page,
          initialChapters: story.chapters,
          onProgress: AiStorySaver(
            childId: widget.childId,
            config: story.config,
            id: story.id,
          ).save,
        ),
      );
    }
    final saved = await Navigator.of(context).push<SavedStory>(
      MaterialPageRoute(
        builder: (_) => StoryWriterScreen(
          config: story.config,
          childId: widget.childId,
          showIdeas: _ai.sproutIdeas,
          resume: story,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      // Finished now: logged and paid like a story finished in one go.
      final typed = saved.title.trim();
      recordStoryCreated(
        context,
        widget.childId,
        typed.isEmpty || typed == StoryDraft.defaultTitle
            ? storyTitle(story.config)
            : typed,
      );
      await _push(MyStoryScreen(title: saved.title, text: saved.text));
    } else {
      await _refresh();
    }
  }

  /// Books a grown-up added in Child Profile → Manage books. They live on this
  /// device, so they show up as soon as the dashboard opens.
  Future<void> _loadBooks() async {
    List<Book> books;
    try {
      books = await _library.load();
    } catch (_) {
      books = [];
    }
    if (!mounted) return;
    setState(() => _books = _byRecent(books));
    // Books added before EPUB 3 covers were read get theirs, once, without
    // holding up the shelf: the cards show now and the covers follow. The
    // result is used as is, not reloaded, so a book with no cover at all
    // can't send this round again.
    if (books.any((b) => b.coverPath == null)) {
      _library.fillMissingCovers().then((filled) {
        if (mounted) setState(() => _books = _byRecent(filled));
      }, onError: (_) {});
    }
  }

  /// Same order as the shelf: the book they were last in comes first.
  static List<Book> _byRecent(List<Book> books) => [...books]
    ..sort(
      (a, b) =>
          (b.lastOpenedAt ?? b.addedAt).compareTo(a.lastOpenedAt ?? a.addedAt),
    );

  void _openBook(Book book) => _guarded(
    ReadingModulePage(
      childId: widget.childId,
      childName: widget.childName,
      book: book,
      library: _library,
    ),
  );

  Future<void> _loadRules() async {
    AiSettings ai;
    ChildRules rules;
    List<ActivityEvent> events;
    try {
      ai = await FamilySettings.instance.load();
      rules = await FamilySettings.instance.loadChild(widget.childId);
      events = await ActivityService.instance.getEvents(widget.childId);
    } catch (_) {
      return;
    }
    // Everything Gemini writes from here on is pitched at this child.
    ReaderAudience.current = rules.ageBand;
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _ai = ai;
      _rules = rules;
      _minutesToday = minutesReadToday(events, now);
      _readToday = readToday(events, now);
    });
  }

  /// The daily reading limit is used up and no grown-up has lifted it.
  bool get _locked => _rules.limitReached(_minutesToday, DateTime.now());

  /// Opens [screen] unless today's time is used up.
  void _guarded(Widget screen) => _locked ? _showDoneForToday() : _push(screen);

  Future<void> _showDoneForToday() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _DoneForTodaySheet(
      onUnlock: () {
        Navigator.pop(sheetContext);
        _unlock();
      },
    ),
  );

  Future<void> _unlock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _GrownUpPinDialog(),
    );
    if (ok != true) return;
    try {
      await FamilySettings.instance.unlockToday(widget.childId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't unlock. Try again.")),
        );
      }
      return;
    }
    await _loadRules();
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
    // Coins earned, and reading time used, while it was open.
    await _refresh();
  }

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

  void _openLibrary() => _guarded(
    ReadingLibraryScreen(childId: widget.childId, childName: widget.childName),
  );

  void _createStory() => _guarded(
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
          if (_locked) ...[
            _Banner(
              key: const Key('done-for-today'),
              emoji: '🌙',
              title: 'All done for today!',
              message:
                  'You read for $_minutesToday minutes. Great job! '
                  'Come back tomorrow for more stories.',
              action: 'Grown-up unlock',
              onAction: _unlock,
            ),
            const SizedBox(height: 16),
          ] else if (_ai.readingReminder && !_readToday) ...[
            _Banner(
              key: const Key('reading-reminder'),
              emoji: '📚',
              title: "You haven't read today",
              message: "Let's read a story together!",
              action: 'Read now',
              onAction: _openLibrary,
            ),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader('My Books'),
          const SizedBox(height: 12),
          ..._buildMyBooks(),
          const SizedBox(height: 24),
          _buildSectionHeader('My Stories'),
          const SizedBox(height: 12),
          ..._buildFinishedStories(),
          const SizedBox(height: 24),
          _buildSectionHeader('Still Working On'),
          const SizedBox(height: 12),
          ..._buildUnfinishedStories(),
          // The ideas are written by AI, so they go when AI stories do.
          if (_ai.aiStories) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Story Ideas'),
            const SizedBox(height: 12),
            _buildBookGrid([
              for (final preset in _storyPresets)
                _BookCard(
                  title: preset.title,
                  emoji: preset.emoji,
                  onTap: () => _guarded(
                    StoryReaderScreen(
                      config: preset.config,
                      childId: widget.childId,
                      childName: widget.childName,
                      // Kept like any story Sprout writes with them.
                      onProgress: AiStorySaver(
                        childId: widget.childId,
                        config: preset.config,
                      ).save,
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  /// Finished stories only; with none yet, a card that starts one.
  List<Widget> _buildFinishedStories() {
    final stories = _stories;
    if (stories == null) return const [];
    final finished = stories.where((s) => s.completed).toList()
      ..sort(
        (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
          a.completedAt ?? DateTime(0),
        ),
      );
    return [
      _storyRow([
        for (final story in finished)
          _StoryCard(
            title: story.title,
            emoji: _settingEmoji(story.config.setting),
            caption: story.byAi ? 'With Sprout' : 'By you',
            onTap: () => _readStory(story),
          ),
        if (finished.isEmpty) _NewStoryCard(onTap: _createStory),
      ]),
    ];
  }

  /// Stories begun and not finished: tap to carry on.
  List<Widget> _buildUnfinishedStories() {
    final stories = _stories;
    if (stories == null) return const [];
    final unfinished = stories.where((s) => !s.completed).toList();
    if (unfinished.isEmpty) {
      return const [
        Text(
          "Stories you start but don't finish will wait for you here.",
          key: Key('no-unfinished-stories'),
          style: TextStyle(color: Colors.black54),
        ),
      ];
    }
    return [
      _storyRow([
        for (final story in unfinished)
          _StoryCard(
            title: story.title,
            emoji: _settingEmoji(story.config.setting),
            caption: story.byAi ? 'Keep reading' : 'Keep writing',
            unfinished: true,
            onTap: () => _resumeStory(story),
          ),
      ]),
    ];
  }

  Widget _storyRow(List<Widget> cards) => SizedBox(
    height: 190,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => SizedBox(width: 140, child: cards[i]),
    ),
  );

  static String _settingEmoji(String? setting) => switch (setting) {
    'Forest' => '🌲',
    'Ocean' => '🌊',
    'City' => '🏙️',
    'Outer Space' => '🚀',
    _ => '📖',
  };

  List<Widget> _buildMyBooks() {
    final books = _books;
    if (books == null) return const [];
    if (books.isEmpty) {
      return [
        Container(
          key: const Key('no-books'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Text('📚', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text(
                'No books yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Ask a grown-up to add some books for you.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _buildBookGrid([
        for (final book in books.take(_homeBooks))
          _BookCard(
            title: book.title,
            emoji: '📖',
            coverPath: book.coverPath,
            caption: book.chapter == 0
                ? 'Ready to read'
                : 'Chapter ${book.chapter} of ${book.chaptersTotal}',
            onTap: () => _openBook(book),
          ),
      ], aspectRatio: 0.58),
      if (books.length > _homeBooks)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openLibrary,
            child: Text('See all ${books.length} books'),
          ),
        ),
    ];
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

  /// [aspectRatio] is a card's width over its height. Books use a taller
  /// card so the whole cover shows: most covers are about 2:3, and with the
  /// title and progress line under it, 0.58 leaves the picture close to that.
  Widget _buildBookGrid(List<Widget> cards, {double aspectRatio = 0.75}) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: cards,
    );
  }

  // Placeholder tabs — bottom nav navigates away for read/create
  Widget _buildReadTab() => const SizedBox.shrink();
  Widget _buildMyStoriesTab() => const SizedBox.shrink();
}

/// One of the child's stories in a row on the home tab.
class _StoryCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String caption;
  final bool unfinished;
  final VoidCallback onTap;

  const _StoryCard({
    required this.title,
    required this.emoji,
    required this.caption,
    required this.onTap,
    this.unfinished = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $caption',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: unfinished
                      ? Colors.amber.shade50
                      : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.shade300,
                    width: unfinished ? 1 : 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 44)),
                    ),
                    if (unfinished)
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: Icon(Icons.edit_note, color: Colors.black45),
                      ),
                  ],
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
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the finished stories go before there are any: a grey card with a
/// plus that starts one.
class _NewStoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NewStoryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create a story',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const Key('new-story-card'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.add, size: 56, color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a story',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Text(' ', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// A card across the top of the home tab: the reading reminder, or the
/// daily limit being used up.
class _Banner extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  const _Banner({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                  ),
                  child: Text(action),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the child taps Read or Create after today's time is used up.
class _DoneForTodaySheet extends StatelessWidget {
  final VoidCallback onUnlock;

  const _DoneForTodaySheet({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'All done for today!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "You've used today's reading time. Come back tomorrow!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onUnlock,
                    child: const Text('Grown-up unlock'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The parent PIN, to lift today's limit.
class _GrownUpPinDialog extends StatefulWidget {
  const _GrownUpPinDialog();

  @override
  State<_GrownUpPinDialog> createState() => _GrownUpPinDialogState();
}

class _GrownUpPinDialogState extends State<_GrownUpPinDialog> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pin.text == ParentPinScreen.parentPin) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Incorrect PIN. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grown-up unlock'),
      content: TextField(
        controller: _pin,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: InputDecoration(
          labelText: 'Parent PIN',
          errorText: _error,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
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

  /// Shown when there is no cover, or it can't be read.
  final String emoji;

  /// The book's cover image on this device, if it has one.
  final String? coverPath;

  /// A line under the title, such as how far through the book they are.
  final String? caption;
  final VoidCallback onTap;

  const _BookCard({
    required this.title,
    required this.emoji,
    required this.onTap,
    this.coverPath,
    this.caption,
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
              clipBehavior: Clip.antiAlias,
              child: BookCover(path: coverPath, fallback: _emojiCover()),
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
          if (caption != null)
            Text(
              caption!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _emojiCover() =>
      Center(child: Text(emoji, style: const TextStyle(fontSize: 48)));
}
