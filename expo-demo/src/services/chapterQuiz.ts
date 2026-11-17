/**
 * Decides when a book's end-of-chapter quiz should appear, ported from
 * lib/screens/chapter_quiz.dart. Each reader reports where the child is in
 * the book's contents; this works out when they have just read past the end
 * of a chapter.
 */

const CHAPTER_WORD = /^\s*(chapter|ch\.)\s/i;
/** A title led by its chapter number: "XII. Council of War", "12. The End". */
const CHAPTER_NUMBER = /^\s*([IVXLC]+|\d+)([.:)]|\s|$)/;
const PART_TITLE = /^\s*(part|book)\b/i;

const isChapter = (title: string) => CHAPTER_WORD.test(title) || CHAPTER_NUMBER.test(title);

export type QuizContentsEntry = { title: string; depth: number };

/** A chapter just finished: contents entries [entry] up to (not including) [end]. */
export type FinishedChapter = { title: string; number: number; entry: number; end: number };

export class ChapterQuizTrigger {
  private contents: QuizContentsEntry[];
  private quizzable: Map<number, number>;
  private done = new Set<number>();
  private chapter: number | null = null;

  constructor(contents: QuizContentsEntry[]) {
    this.contents = contents;
    this.quizzable = ChapterQuizTrigger.quizChapters(contents);
  }

  /**
   * Real chapters get a quiz; front and back matter doesn't, nor do part
   * title pages in a book with chapters. Failing chapters, parts get a quiz;
   * failing both, every top-level entry does.
   */
  private static quizChapters(contents: QuizContentsEntry[]): Map<number, number> {
    const topLevel = contents.map((c, i) => (c.depth === 0 ? i : -1)).filter((i) => i >= 0);
    const chapters = topLevel.filter((i) => isChapter(contents[i].title));
    const parts = topLevel.filter((i) => PART_TITLE.test(contents[i].title));
    const quizzed = chapters.length ? chapters : parts.length ? parts : topLevel;
    return new Map(quizzed.map((entry, n) => [entry, n + 1]));
  }

  /**
   * Reports that the child is now in contents entry [entry]. [pageTurn] is
   * false for jumps, which never trigger a quiz. Returns the chapter just
   * finished when a quiz is due.
   */
  moveTo(entry: number | null, pageTurn: boolean): FinishedChapter | null {
    const previous = this.chapter;
    const current = entry == null ? null : this.chapterOf(entry);
    this.chapter = current;
    if (!pageTurn || previous == null || current == null) return null;
    if (!this.follows(previous, current)) return null;
    const number = this.quizzable.get(previous);
    if (number == null || this.done.has(previous)) return null;
    this.done.add(previous);
    return {
      title: this.contents[previous].title,
      number,
      entry: previous,
      end: this.nextChapter(previous) ?? this.contents.length,
    };
  }

  private follows(previous: number, current: number): boolean {
    if (current <= previous) return false;
    for (let i = previous + 1; i < current; i++) if (this.quizzable.has(i)) return false;
    return true;
  }

  private chapterOf(entry: number): number {
    for (let i = entry; i >= 0; i--) if (this.contents[i].depth === 0) return i;
    return entry;
  }

  private nextChapter(chapter: number): number | null {
    for (let i = chapter + 1; i < this.contents.length; i++) if (this.contents[i].depth === 0) return i;
    return null;
  }
}
