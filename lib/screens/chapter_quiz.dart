/// Decides when a book's end-of-chapter quiz should appear.
///
/// Every reader view (picture book, paged text, scrolling text) reports where
/// the child is in the book's contents; this works out when they have just
/// read past the end of a chapter.
library;

final _chapterTitle = RegExp(
  r'^\s*(chapter|part|book)\b',
  caseSensitive: false,
);

/// One contents entry, as the trigger sees it.
typedef QuizContentsEntry = ({String title, int depth});

/// A chapter the child has just finished.
typedef FinishedChapter = ({String title, int number});

class ChapterQuizTrigger {
  /// [contents] is the book's contents in order. Only top-level entries count
  /// as chapters; nested entries belong to the chapter above them.
  ChapterQuizTrigger(List<QuizContentsEntry> contents)
    : _contents = contents,
      _quizzable = _quizChapters(contents);

  final List<QuizContentsEntry> _contents;

  /// Entry index -> 1-based chapter number, for entries that get a quiz.
  final Map<int, int> _quizzable;
  final _done = <int>{};
  int? _chapter;

  /// Real chapters get a quiz; front and back matter ("Contents",
  /// "Copyright", "How to Draw") doesn't. A book whose entries aren't titled
  /// "Chapter…"/"Part…"/"Book…" gets a quiz after every top-level entry.
  static Map<int, int> _quizChapters(List<QuizContentsEntry> contents) {
    final topLevel = [
      for (var i = 0; i < contents.length; i++)
        if (contents[i].depth == 0) i,
    ];
    final named = [
      for (final i in topLevel)
        if (_chapterTitle.hasMatch(contents[i].title)) i,
    ];
    final chapters = named.isNotEmpty ? named : topLevel;
    return {for (var n = 0; n < chapters.length; n++) chapters[n]: n + 1};
  }

  /// Reports that the child is now in contents entry [entry] (null when the
  /// position is before the first entry).
  ///
  /// [pageTurn] is false for jumps (Contents, reopening the book), which never
  /// trigger a quiz. Returns the chapter just finished when a quiz is due:
  /// the child turned a page from a quiz chapter straight into the chapter
  /// that follows it, and hasn't been quizzed on it yet.
  FinishedChapter? moveTo(int? entry, {required bool pageTurn}) {
    final previous = _chapter;
    final current = entry == null ? null : _chapterOf(entry);
    _chapter = current;
    if (!pageTurn || previous == null || current == null) return null;
    if (current != _nextChapter(previous)) return null;
    final number = _quizzable[previous];
    if (number == null || !_done.add(previous)) return null;
    return (title: _contents[previous].title, number: number);
  }

  /// The top-level entry [entry] belongs to.
  int _chapterOf(int entry) {
    for (var i = entry; i >= 0; i--) {
      if (_contents[i].depth == 0) return i;
    }
    return entry;
  }

  int? _nextChapter(int chapter) {
    for (var i = chapter + 1; i < _contents.length; i++) {
      if (_contents[i].depth == 0) return i;
    }
    return null;
  }
}
