/// Decides when a book's end-of-chapter quiz should appear.
///
/// Every reader view (picture book, paged text, scrolling text) reports where
/// the child is in the book's contents; this works out when they have just
/// read past the end of a chapter.
library;

/// "Chapter 3", "CHAPTER I.".
final _chapterWord = RegExp(r'^\s*(chapter|ch\.)\s', caseSensitive: false);

/// A title led by its chapter number: a Roman numeral ("I The Old
/// Sea-dog…", "XII. Council of War"; capitals only, so "Civil War" isn't
/// one) or digits ("1 The Start", "12. The End").
final _chapterNumber = RegExp(r'^\s*([IVXLC]+|\d+)([.:)]|\s|$)');

/// "Part One", "BOOK II": groupings of chapters.
final _partTitle = RegExp(r'^\s*(part|book)\b', caseSensitive: false);

bool _isChapter(String title) =>
    _chapterWord.hasMatch(title) || _chapterNumber.hasMatch(title);

/// One contents entry, as the trigger sees it.
typedef QuizContentsEntry = ({String title, int depth});

/// A chapter the child has just finished: contents entries [entry] up to
/// (not including) [end], the next top-level entry or the end of the book.
typedef FinishedChapter = ({String title, int number, int entry, int end});

/// How a reader view reports a due quiz. [from] and [to] (exclusive) are the
/// finished chapter's extent in the view's own units (spine files, pages),
/// so the quiz can be written from what the chapter actually contains.
typedef ChapterEndCallback =
    void Function(FinishedChapter chapter, int from, int to);

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
  /// "Copyright", "How to Draw") doesn't, and nor do part title pages in a
  /// book with chapters (Treasure Island's "PART ONE—The Old Buccaneer"
  /// sits between its chapters at the same level). Failing chapters, parts
  /// get a quiz; failing both, every top-level entry does.
  static Map<int, int> _quizChapters(List<QuizContentsEntry> contents) {
    final topLevel = [
      for (var i = 0; i < contents.length; i++)
        if (contents[i].depth == 0) i,
    ];
    final chapters = [
      for (final i in topLevel)
        if (_isChapter(contents[i].title)) i,
    ];
    final parts = [
      for (final i in topLevel)
        if (_partTitle.hasMatch(contents[i].title)) i,
    ];
    final quizzed = chapters.isNotEmpty
        ? chapters
        : parts.isNotEmpty
        ? parts
        : topLevel;
    return {for (var n = 0; n < quizzed.length; n++) quizzed[n]: n + 1};
  }

  /// Reports that the child is now in contents entry [entry] (null when the
  /// position is before the first entry).
  ///
  /// [pageTurn] is false for jumps (Contents, reopening the book), which never
  /// trigger a quiz. Returns the chapter just finished when a quiz is due:
  /// the child turned a page from a quiz chapter straight into what follows
  /// it, and hasn't been quizzed on it yet.
  FinishedChapter? moveTo(int? entry, {required bool pageTurn}) {
    final previous = _chapter;
    final current = entry == null ? null : _chapterOf(entry);
    _chapter = current;
    if (!pageTurn || previous == null || current == null) return null;
    if (!_follows(previous, current)) return null;
    final number = _quizzable[previous];
    if (number == null || !_done.add(previous)) return null;
    return (
      title: _contents[previous].title,
      number: number,
      entry: previous,
      end: _nextChapter(previous) ?? _contents.length,
    );
  }

  /// Whether moving from [previous] to [current] is reading on rather than a
  /// jump: [current] comes after it with no other quiz chapter in between.
  /// Entries in between can be passed without the reader ever reporting
  /// them: a part's title page that shares a file with a chapter ("PART
  /// TWO" between Treasure Island's chapters VI and VII) goes by in the
  /// same page turn.
  bool _follows(int previous, int current) {
    if (current <= previous) return false;
    for (var i = previous + 1; i < current; i++) {
      if (_quizzable.containsKey(i)) return false;
    }
    return true;
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
