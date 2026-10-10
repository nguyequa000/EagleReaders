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
import 'sticker_kit.dart';
import 'story/paper_background.dart';
import 'story/story_button.dart';
import 'story/story_theme.dart';

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

  /// How many books Currently Reading shows before "See all".
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

  /// Books a grown-up gave this child in Manage Shelf. They live on this
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

  /// My Library is a tab of its own; the books in it are what the daily
  /// limit guards, not looking at them.
  void _showLibrary() => setState(() => _selectedTab = 1);

  void _createStory() => _guarded(
    StoryFlowScreen(childId: widget.childId, childName: widget.childName),
  );

  void _openRewards() => _push(
    ChildRewardsScreen(childId: widget.childId, childName: widget.childName),
  );

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    // Back from My Library goes Home rather than leaving the dashboard.
    return PopScope(
      canPop: _selectedTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedTab = 0);
      },
      child: Scaffold(
        backgroundColor: palette.ground,
        body: PaperBackground(
          child: Column(
            children: [
              StickerHeader(
                title: 'Hi ${widget.childName}! 🌱',
                trailing: [
                  if (_coins != null)
                    _CoinChip(coins: _coins!, onTap: _openRewards),
                  StickerIconButton(
                    icon: Icons.redeem,
                    tooltip: 'My Rewards',
                    onTap: _openRewards,
                  ),
                  StickerIconButton(icon: Icons.search, onTap: () {}),
                  const ThemeSticker(),
                ],
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _buildHomeTab(),
                    _buildLibraryTab(),
                    // Create a Story opens the story flow instead.
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _StickerNavBar(
          currentIndex: _selectedTab,
          onTap: (index) {
            if (index == 2) return _createStory();
            setState(() => _selectedTab = index);
          },
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      // The extra room at the bottom keeps the last row's hard shadows clear
      // of the nav bar's edge.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              onAction: _showLibrary,
            ),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader('Currently Reading'),
          const SizedBox(height: 12),
          ..._buildCurrentlyReading(),
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
              for (final (i, preset) in _storyPresets.indexed)
                _BookCard(
                  index: i,
                  tinted: true,
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
        for (final (i, story) in finished.indexed)
          _StoryCard(
            index: i,
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
      return [
        Text(
          "Stories you start but don't finish will wait for you here.",
          key: const Key('no-unfinished-stories'),
          style: StoryTheme.body(color: StoryTheme.of(context).inkMuted),
        ),
      ];
    }
    return [
      _storyRow([
        for (final (i, story) in unfinished.indexed)
          _StoryCard(
            index: i,
            title: story.title,
            emoji: _settingEmoji(story.config.setting),
            caption: story.byAi ? 'Keep reading' : 'Keep writing',
            unfinished: true,
            onTap: () => _resumeStory(story),
          ),
      ]),
    ];
  }

  /// A sideways-scrolling row. The padding gives the tilted cards and their
  /// hard shadows room, so the list's edges don't shave their corners off.
  Widget _storyRow(List<Widget> cards) => SizedBox(
    height: 200,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
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

  /// The books the child has opened, the one they were last in first. A book
  /// they haven't started yet waits in My Library.
  List<Widget> _buildCurrentlyReading() {
    final books = _books;
    if (books == null) return const [];
    if (books.isEmpty) return [_buildNoBooks()];
    final palette = StoryTheme.of(context);
    final reading = books.where((b) => b.lastOpenedAt != null).toList();
    if (reading.isEmpty) {
      return [
        StickerCard(
          key: const Key('nothing-being-read'),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Text('📚', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  'Pick a book to start',
                  style: StoryTheme.display(
                    size: 18,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your books are waiting in My Library.',
                  textAlign: TextAlign.center,
                  style: StoryTheme.body(color: palette.inkMuted),
                ),
                const SizedBox(height: 12),
                StoryButton(
                  label: 'Open My Library',
                  accent: palette.action,
                  onPressed: _showLibrary,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final shown = reading.take(_homeBooks).toList();
    return [
      _buildBooks(shown),
      if (books.length > shown.length) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: StickerPill(
            onTap: _showLibrary,
            color: palette.action,
            child: Text(
              'See all ${books.length} books',
              style: StoryTheme.display(
                size: 14,
                color: palette.onAction,
                weight: 700,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  /// Every book a grown-up has added for this child, A to Z.
  Widget _buildLibraryTab() {
    final books = _books;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('My Library'),
          const SizedBox(height: 12),
          if (books != null)
            books.isEmpty
                ? _buildNoBooks()
                : _buildBooks(
                    [...books]..sort(
                      (a, b) => a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  /// [books] as a grid of covers, each opening its book.
  Widget _buildBooks(List<Book> books) => _buildBookGrid([
    for (final (i, book) in books.indexed)
      _BookCard(
        index: i,
        title: book.title,
        emoji: '📖',
        coverPath: book.coverPath,
        caption: book.chapter == 0
            ? 'Ready to read'
            : 'Chapter ${book.chapter} of ${book.chaptersTotal}',
        onTap: () => _openBook(book),
      ),
  ], aspectRatio: 0.58);

  Widget _buildNoBooks() {
    final palette = StoryTheme.of(context);
    return StickerCard(
      key: const Key('no-books'),
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const Text('📚', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              'No books yet',
              style: StoryTheme.display(
                size: 18,
                color: palette.ink,
                weight: 700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask a grown-up to add some books for you.',
              textAlign: TextAlign.center,
              style: StoryTheme.body(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Which tint each section's title tag wears, so the page reads as a run
  /// of different stickers rather than one repeated label.
  static const _sectionTints = {
    'Currently Reading': 1,
    'My Library': 1,
    'My Stories': 2,
    'Still Working On': 3,
    'Story Ideas': 4,
  };

  Widget _buildSectionHeader(String title) {
    final palette = StoryTheme.of(context);
    final index = _sectionTints[title] ?? 0;
    return Row(
      children: [
        StickerPill(
          color: palette.tintForIndex(index),
          tilt: stickerTilt(index),
          child: Text(
            title,
            style: StoryTheme.display(
              size: 18,
              color: palette.ink,
              weight: 700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: StoryTheme.outlineWidthThin,
            decoration: BoxDecoration(
              color: palette.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
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
      // Room for the tilted corners and hard shadows on the outer cards.
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(2, 4, 6, 8),
      crossAxisCount: 2,
      crossAxisSpacing: 18,
      mainAxisSpacing: 18,
      childAspectRatio: aspectRatio,
      children: cards,
    );
  }
}

/// One of the child's stories in a row on the home tab: a tinted sticker,
/// tipped like the story tiles. An unfinished one is plain paper with a
/// pencil badge, so the two rows don't read the same.
class _StoryCard extends StatelessWidget {
  final int index;
  final String title;
  final String emoji;
  final String caption;
  final bool unfinished;
  final VoidCallback onTap;

  const _StoryCard({
    required this.index,
    required this.title,
    required this.emoji,
    required this.caption,
    required this.onTap,
    this.unfinished = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
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
              child: StickerCard(
                color: unfinished
                    ? palette.surface
                    : palette.tintForIndex(index),
                tilt: stickerTilt(index),
                child: Stack(
                  children: [
                    Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 44)),
                    ),
                    if (unfinished)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _Badge(icon: Icons.edit, color: palette.action),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CardTitle(title: title, caption: caption),
          ],
        ),
      ),
    );
  }
}

/// A small round sticker in a card's corner.
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.outline,
          width: StoryTheme.outlineWidthThin,
        ),
      ),
      child: Icon(icon, size: 14, color: palette.onAction),
    );
  }
}

/// The title and caption under a card.
class _CardTitle extends StatelessWidget {
  final String title;
  final String? caption;

  const _CardTitle({required this.title, this.caption});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: StoryTheme.display(size: 14, color: palette.ink, weight: 700),
        ),
        if (caption != null)
          Text(
            caption!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StoryTheme.body(
              size: 12,
              color: palette.inkMuted,
              weight: 600,
              height: 1.3,
            ),
          ),
      ],
    );
  }
}

/// Where the finished stories go before there are any: a paper sticker with
/// a plus that starts one.
class _NewStoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NewStoryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
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
              child: StickerCard(
                tilt: stickerTilt(0),
                child: Center(
                  child: Icon(Icons.add, size: 56, color: palette.ink),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _CardTitle(title: 'Create a story', caption: ' '),
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
    final palette = StoryTheme.of(context);
    return StickerCard(
      color: palette.tintYellow,
      tilt: stickerTilt(4),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: StoryTheme.display(
                    size: 18,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: StoryTheme.body(color: palette.ink, weight: 500),
                ),
                const SizedBox(height: 12),
                StoryButton(
                  label: action,
                  accent: palette.action,
                  onPressed: onAction,
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
    final palette = StoryTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.ground,
        border: Border(
          top: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌙', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                'All done for today!',
                style: StoryTheme.display(
                  size: 22,
                  color: palette.ink,
                  weight: 700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You've used today's reading time. Come back tomorrow!",
                textAlign: TextAlign.center,
                style: StoryTheme.body(color: palette.ink),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StoryButton(
                      key: const Key('sheet-unlock'),
                      label: 'Grown-up unlock',
                      accent: palette.action,
                      filled: false,
                      showArrow: false,
                      onPressed: onUnlock,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StoryButton(
                      label: 'OK',
                      accent: palette.action,
                      showArrow: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final palette = StoryTheme.of(context);
    final actionStyle = TextButton.styleFrom(
      foregroundColor: palette.ink,
      textStyle: StoryTheme.display(size: 16, color: palette.ink, weight: 700),
    );
    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StoryTheme.radiusTile),
        side: BorderSide(
          color: palette.outline,
          width: StoryTheme.outlineWidth,
        ),
      ),
      title: Text(
        'Grown-up unlock',
        style: StoryTheme.display(size: 20, color: palette.ink, weight: 700),
      ),
      content: TextField(
        controller: _pin,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        style: StoryTheme.body(color: palette.ink),
        decoration: stickerInputDecoration(
          palette,
          label: 'Parent PIN',
          errorText: _error,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          style: actionStyle,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: actionStyle,
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// The child's coin balance in the header; tapping it opens My Rewards.
class _CoinChip extends StatelessWidget {
  final int coins;
  final VoidCallback onTap;

  const _CoinChip({required this.coins, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return StickerPill(
      onTap: onTap,
      child: Text(
        '🪙 $coins',
        key: const Key('coinBalance'),
        style: StoryTheme.display(size: 16, color: palette.ink, weight: 700),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  /// Position in the grid, which picks the card's tilt (and tint, when
  /// [tinted]).
  final int index;

  /// Fills the card with a sticker tint rather than paper — for story ideas,
  /// which have an emoji where a book has its cover.
  final bool tinted;

  final String title;

  /// Shown when there is no cover, or it can't be read.
  final String emoji;

  /// The book's cover image on this device, if it has one.
  final String? coverPath;

  /// A line under the title, such as how far through the book they are.
  final String? caption;
  final VoidCallback onTap;

  const _BookCard({
    required this.index,
    required this.title,
    required this.emoji,
    required this.onTap,
    this.tinted = false,
    this.coverPath,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StickerCard(
              color: tinted ? palette.tintForIndex(index) : palette.surface,
              tilt: stickerTilt(index),
              radius: StoryTheme.radiusButton,
              child: SizedBox.expand(
                child: BookCover(path: coverPath, fallback: _emojiCover()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _CardTitle(title: title, caption: caption),
        ],
      ),
    );
  }

  Widget _emojiCover() =>
      Center(child: Text(emoji, style: const TextStyle(fontSize: 48)));
}

/// Home, My Library and Create as three stickers on a yellow band, cut off from
/// the page with the ink line like the header. The current tab is the one in
/// the action colour; each is tipped a little, like the story tiles.
class _StickerNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _StickerNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.local_library, label: 'My Library'),
    (icon: Icons.edit, label: 'Create a Story'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.header,
        border: Border(
          top: BorderSide(
            color: palette.outline,
            width: StoryTheme.outlineWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
          child: Row(
            children: [
              for (final (i, item) in _items.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _navTab(palette, i, item.icon, item.label)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTab(StoryPalette palette, int i, IconData icon, String label) {
    final current = i == currentIndex;
    final ink = current ? palette.onAction : palette.ink;
    return StickerCard(
      color: current ? palette.action : palette.surface,
      tilt: stickerTilt(i + 2),
      radius: StoryTheme.radiusButton,
      depth: 3,
      semanticLabel: label,
      onTap: () => onTap(i),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: ink),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: StoryTheme.display(size: 13, color: ink, weight: 700),
            ),
          ),
        ],
      ),
    );
  }
}
