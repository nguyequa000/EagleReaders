import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import 'live_refresh.dart';
import 'reading_library_screen.dart';

/// Parent-facing view of one child's reading profile and book shelf.
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
    refreshOn(
      () => [ActivityService.instance.changes(widget.childId)],
      _load,
    );
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
    final stats = _stats;
    final l10n = MaterialLocalizations.of(context);
    final score = stats?.lastComprehensionScorePct;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("${widget.childName}'s Profile"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    child: const Text('🧒', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    widget.childName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.library_add, color: Colors.green),
                    title: Text("Manage ${widget.childName}'s books"),
                    subtitle: const Text('Add or remove EPUB books'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReadingLibraryScreen(
                          childId: widget.childId,
                          childName: widget.childName,
                          canManage: true,
                        ),
                      ),
                    ),
                  ),
                ),
                _tile(
                  Icons.menu_book,
                  'Books finished',
                  '${stats?.booksFinished ?? 0}',
                ),
                _tile(
                  Icons.timer,
                  'Minutes read this week',
                  '${stats?.minutesThisWeek ?? 0}',
                ),
                _tile(
                  Icons.edit_note,
                  'Stories created',
                  '${stats?.storiesCreated ?? 0}',
                ),
                _tile(
                  Icons.quiz,
                  'Last quiz score',
                  score == null ? 'No quiz yet' : '${score.round()}%',
                ),
                _tile(
                  Icons.bookmark,
                  'Currently reading',
                  stats?.currentlyReading ?? 'Nothing right now',
                ),
                const SizedBox(height: 20),
                const Text(
                  'All Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_events.isEmpty)
                  const Card(child: ListTile(title: Text('No activity yet.')))
                else
                  for (final event in _events.reversed)
                    Card(
                      child: ListTile(
                        title: Text(event.describe(widget.childName)),
                        subtitle: Text(
                          '${l10n.formatShortDate(event.dateTime)} '
                          '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(event.dateTime))}',
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Card(
    child: ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );
}
