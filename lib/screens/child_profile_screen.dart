import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import 'live_refresh.dart';
import 'book_shelf_screen.dart';
import 'sticker_kit.dart';
import 'story/story_theme.dart';

/// Parent-facing view of one child's reading profile, and which of the
/// family's books they have.
///
/// Activity is keyed by [childId] (see [ActivityService]); [childName] is
/// only for display.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen>
    with LiveRefresh {
  List<ActivityEvent> _events = [];
  ChildActivityStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Reading the child is doing right now, on their own device.
    refreshOn(() => [ActivityService.instance.changes(widget.childId)], _load);
  }

  Future<void> _load() async {
    final events = await ActivityService.instance.getEvents(widget.childId);
    final stats = ActivityService.statsFrom(events);
    if (!mounted) return;
    setState(() {
      _events = events;
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    final stats = _stats;
    final l10n = MaterialLocalizations.of(context);
    final score = stats?.lastComprehensionScorePct;
    return StickerPage(
      title: "${widget.childName}'s Profile",
      forParent: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Extra room right and below for the hard shadows.
              padding: const EdgeInsets.fromLTRB(18, 20, 22, 28),
              children: [
                Center(
                  child: StickerEmoji(
                    emoji: '🧒',
                    color: palette.tintYellow,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    widget.childName,
                    style: StoryTheme.display(
                      size: 24,
                      color: palette.ink,
                      weight: 700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StickerRow(
                  leading: StickerIconDisc(
                    icon: Icons.library_add,
                    color: palette.tintGreen,
                  ),
                  title: "Choose ${widget.childName}'s books",
                  subtitle: 'Pick books from the family shelf',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChildShelfScreen(
                        childId: widget.childId,
                        childName: widget.childName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const StickerSectionTitle('Reading'),
                _tile(
                  Icons.menu_book,
                  palette.tintBlue,
                  'Books finished',
                  '${stats?.booksFinished ?? 0}',
                ),
                _tile(
                  Icons.timer,
                  palette.tintCoral,
                  'Minutes read this week',
                  '${stats?.minutesThisWeek ?? 0}',
                ),
                _tile(
                  Icons.edit_note,
                  palette.tintMagenta,
                  'Stories created',
                  '${stats?.storiesCreated ?? 0}',
                ),
                _tile(
                  Icons.quiz,
                  palette.tintGreen,
                  'Last quiz score',
                  score == null ? 'No quiz yet' : '${score.round()}%',
                ),
                _tile(
                  Icons.bookmark,
                  palette.tintYellow,
                  'Currently reading',
                  stats?.currentlyReading ?? 'Nothing right now',
                ),
                const SizedBox(height: 14),
                const StickerSectionTitle('All Activity'),
                if (_events.isEmpty)
                  StickerRow(
                    leading: StickerIconDisc(
                      icon: Icons.info_outline,
                      color: palette.surface,
                      size: 34,
                    ),
                    title: 'No activity yet.',
                  )
                else
                  for (final event in _events.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StickerRow(
                        leading: StickerIconDisc(
                          icon: event.type == 'story_created'
                              ? Icons.edit
                              : Icons.menu_book,
                          color: event.type == 'story_created'
                              ? palette.tintMagenta
                              : palette.tintBlue,
                          size: 34,
                        ),
                        title: event.describe(widget.childName),
                        subtitle:
                            '${l10n.formatShortDate(event.dateTime)} '
                            '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(event.dateTime))}',
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, Color tint, String label, String value) {
    final palette = StoryTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StickerRow(
        leading: StickerIconDisc(icon: icon, color: tint, size: 38),
        title: label,
        // Capped, because a long book file name would otherwise take the whole
        // row and fail layout, blanking the screen.
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: StoryTheme.display(
              size: 16,
              color: palette.ink,
              weight: 700,
            ),
          ),
        ),
      ),
    );
  }
}
