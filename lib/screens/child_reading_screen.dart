import 'package:flutter/material.dart';

import '../services/activity_service.dart';
import '../services/chapter_talk.dart';
import 'live_refresh.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

/// "Talk about it": what a child is reading, how far they've got, and
/// questions the parent can ask about the chapter they just finished (see
/// [ChapterTalkService]; the child's device writes them at each chapter end).
class ChildReadingScreen extends StatefulWidget {
  const ChildReadingScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.bookTitle,
  });

  final String childId;
  final String childName;

  /// The book to talk about; the one with the latest finished chapter when
  /// null.
  final String? bookTitle;

  @override
  State<ChildReadingScreen> createState() => _ChildReadingScreenState();
}

class _ChildReadingScreenState extends State<ChildReadingScreen>
    with LiveRefresh {
  List<ChapterTalk> _talks = [];
  List<ActivityEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Questions arrive a few seconds after the chapter ends, on the child's
    // device.
    refreshOn(
      () => [
        ChapterTalkService.instance.changes(widget.childId),
        ActivityService.instance.changes(widget.childId),
      ],
      _load,
    );
  }

  Future<void> _load() async {
    List<ChapterTalk> talks;
    List<ActivityEvent> events;
    try {
      talks = await ChapterTalkService.instance.forChild(widget.childId);
      events = await ActivityService.instance.getEvents(widget.childId);
    } catch (_) {
      talks = [];
      events = [];
    }
    if (!mounted) return;
    setState(() {
      _talks = talks;
      _events = events;
      _loading = false;
    });
  }

  String? get _title => widget.bookTitle ?? _talks.firstOrNull?.title;

  @override
  Widget build(BuildContext context) {
    final title = _title;
    return StickerPage(
      title: 'Talk about it',
      forParent: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Extra room right and below for the hard shadows.
              padding: const EdgeInsets.fromLTRB(18, 20, 22, 28),
              children: title == null ? [_note(_emptyNote())] : _book(title),
            ),
    );
  }

  String _emptyNote() =>
      'When ${widget.childName} finishes a chapter, questions to ask will '
      'show up here.';

  List<Widget> _book(String title) {
    final talks = [
      for (final talk in _talks)
        if (talk.title == title) talk,
    ];
    final latest = talks.firstOrNull;
    return [
      _bookCard(title, talks),
      const SizedBox(height: 24),
      if (latest == null)
        _note(_emptyNote())
      else ...[
        if (latest.summary.isNotEmpty) ...[
          const StickerSectionTitle('In this chapter'),
          _note(latest.summary),
          const SizedBox(height: 24),
        ],
        StickerSectionTitle('Questions to ask ${widget.childName}'),
        Text(
          '${widget.childName} just finished ${_chapterName(latest)} of '
          '"$title". Here are some questions to start a conversation:',
          style: StoryTheme.body(color: StoryTheme.of(context).ink),
        ),
        const SizedBox(height: 12),
        ..._questions(latest),
        if (talks.length > 1) ...[
          const SizedBox(height: 24),
          const StickerSectionTitle('Earlier chapters'),
          for (final talk in talks.skip(1)) _earlier(talk),
        ],
      ],
    ];
  }

  Widget _bookCard(String title, List<ChapterTalk> talks) {
    final palette = StoryTheme.of(context);
    final latest = talks.firstOrNull;
    final minutes = _events
        .where((e) => e.type == 'reading_session' && e.data['title'] == title)
        .fold<int>(
          0,
          (sum, e) => sum + ((e.data['minutes'] as num?) ?? 0).toInt(),
        );
    final quiz = latest == null
        ? null
        : _events
              .where(
                (e) =>
                    e.type == 'comprehension_result' &&
                    e.data['title'] == title &&
                    e.data['chapter'] == latest.chapter,
              )
              .lastOrNull;
    final lines = [
      if (latest != null)
        'Finished ${_chapterName(latest)} · ${_when(latest.finishedAt)}',
      [
        '${talks.length} ${talks.length == 1 ? 'chapter' : 'chapters'} '
            'finished',
        if (minutes > 0) '$minutes min read',
      ].join(' · '),
      if (quiz != null)
        'Chapter quiz: ${quiz.data['correct']} of ${quiz.data['total']} right',
    ];
    return StickerCard(
      color: palette.tintBlue,
      radius: StoryTheme.radiusButton,
      depth: 3,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          StickerIconDisc(icon: Icons.menu_book, color: palette.surface),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: StoryTheme.display(
                    size: 18,
                    color: palette.ink,
                    weight: 700,
                  ),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: StoryTheme.body(size: 14, color: palette.ink),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _questions(ChapterTalk talk) {
    final palette = StoryTheme.of(context);
    return switch (talk.status) {
      ChapterTalkStatus.writing => [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Sprout is writing questions…',
              style: StoryTheme.body(color: palette.inkMuted),
            ),
          ],
        ),
      ],
      ChapterTalkStatus.failed => [
        _note('No questions for this chapter this time.'),
      ],
      ChapterTalkStatus.ready => [
        for (final (i, question) in talk.questions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StickerCard(
              radius: StoryTheme.radiusButton,
              depth: 3,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: StoryTheme.display(size: 16, color: palette.ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      question,
                      style: StoryTheme.body(color: palette.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    };
  }

  Widget _earlier(ChapterTalk talk) {
    final palette = StoryTheme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        _chapterName(talk),
        style: StoryTheme.display(size: 16, color: palette.ink),
      ),
      subtitle: Text(
        _when(talk.finishedAt),
        style: StoryTheme.body(size: 13, color: palette.inkMuted),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        if (talk.summary.isNotEmpty) ...[
          _note(talk.summary),
          const SizedBox(height: 10),
        ],
        ..._questions(talk),
      ],
    );
  }

  Widget _note(String text) => Text(
    text,
    style: StoryTheme.body(color: StoryTheme.of(context).inkMuted),
  );

  /// "Chapter 3: The Pool of Tears", or just the title when it already says
  /// which chapter it is ("CHAPTER I. Down the Rabbit-Hole").
  static String _chapterName(ChapterTalk talk) {
    final title = talk.chapterTitle.trim();
    if (title.isEmpty) return 'Chapter ${talk.chapter}';
    if (RegExp(r'^(chapter\b|ch\.)', caseSensitive: false).hasMatch(title)) {
      return title;
    }
    return 'Chapter ${talk.chapter}: $title';
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    final ago = now.difference(at);
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inHours < 1) {
      return '${ago.inMinutes} ${ago.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    final days = DateUtils.dateOnly(
      now,
    ).difference(DateUtils.dateOnly(at)).inDays;
    return switch (days) {
      0 => 'today',
      1 => 'yesterday',
      _ => '$days days ago',
    };
  }
}
