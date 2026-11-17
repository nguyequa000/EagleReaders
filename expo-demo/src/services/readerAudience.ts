/** How old the child reading is, as the parent set it under Age Restrictions. */
export type AgeBand = 'ages3to5' | 'ages6to8' | 'ages9to10';

export const AGE_BANDS: AgeBand[] = ['ages3to5', 'ages6to8', 'ages9to10'];

/** The default before a parent sets one. */
export const FALLBACK_BAND: AgeBand = 'ages6to8';

export function ageBandFromName(name: unknown): AgeBand {
  return AGE_BANDS.includes(name as AgeBand) ? (name as AgeBand) : FALLBACK_BAND;
}

export const ageBandInfo: Record<
  AgeBand,
  {
    label: string;
    audience: string;
    readingLevel: string;
    pageLength: string;
    quizLevel: string;
    summary: string;
    allowsSpooky: boolean;
  }
> = {
  ages3to5: {
    label: 'Ages 3–5',
    audience: 'kids aged 3 to 5',
    readingLevel: 'Use very short sentences and the simplest everyday words a 4-year-old knows.',
    pageLength: 'Each page is 1 or 2 sentences.',
    quizLevel: 'Use very short questions and answers with words a 4-year-old knows.',
    summary:
      'Very short sentences and the simplest words, 1–2 sentences a page. ' +
      'Quiz questions are extra short. Spooky stories are hidden.',
    allowsSpooky: false,
  },
  ages6to8: {
    label: 'Ages 6–8',
    audience: 'kids aged 6 to 8',
    readingLevel: 'Use short sentences and simple, everyday words a 6-year-old can read.',
    pageLength: 'Each page is 2 to 4 sentences.',
    quizLevel: 'Use short, simple words a 6-year-old can read.',
    summary:
      'Short sentences and everyday words, 2–4 sentences a page. ' +
      'Every story feeling is available. (Used until you choose an age.)',
    allowsSpooky: true,
  },
  ages9to10: {
    label: 'Ages 9–10',
    audience: 'kids aged 9 to 10',
    readingLevel:
      'Use clear sentences a 9-year-old reads easily. Some richer words are ' +
      'fine when the story makes their meaning clear.',
    pageLength: 'Each page is 3 to 5 sentences.',
    quizLevel: 'Use clear words a 9-year-old reads easily.',
    summary:
      'Longer sentences with some richer words, 3–5 sentences a page. ' +
      'Every story feeling is available.',
    allowsSpooky: true,
  },
};

/**
 * The age band of the child using the app right now. One module-level value,
 * as in the Flutter app: everything Gemini writes reads it, and one child at
 * a time uses a device. The child dashboard sets it when a child opens it.
 */
export const ReaderAudience = { current: FALLBACK_BAND as AgeBand };
