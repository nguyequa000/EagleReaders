/// How old the child reading is, as the parent set it under Age Restrictions.
enum AgeBand {
  ages3to5('Ages 3–5'),
  ages6to8('Ages 6–8'),
  ages9to10('Ages 9–10');

  final String label;
  const AgeBand(this.label);

  /// The default before a parent sets one: what every prompt assumed before
  /// age bands existed.
  static const fallback = AgeBand.ages6to8;

  static AgeBand fromName(String? name) => AgeBand.values.firstWhere(
    (band) => band.name == name,
    orElse: () => fallback,
  );

  /// Who the AI is writing for, as the first line of its instructions.
  String get audience => switch (this) {
    AgeBand.ages3to5 => 'kids aged 3 to 5',
    AgeBand.ages6to8 => 'kids aged 6 to 8',
    AgeBand.ages9to10 => 'kids aged 9 to 10',
  };

  /// How the words should read, for the story writer's rules.
  String get readingLevel => switch (this) {
    AgeBand.ages3to5 =>
      'Use very short sentences and the simplest everyday words a '
          '4-year-old knows.',
    AgeBand.ages6to8 =>
      'Use short sentences and simple, everyday words a 6-year-old can read.',
    AgeBand.ages9to10 =>
      'Use clear sentences a 9-year-old reads easily. Some richer words are '
          'fine when the story makes their meaning clear.',
  };

  /// How long each story page is.
  String get pageLength => switch (this) {
    AgeBand.ages3to5 => 'Each page is 1 or 2 sentences.',
    AgeBand.ages6to8 => 'Each page is 2 to 4 sentences.',
    AgeBand.ages9to10 => 'Each page is 3 to 5 sentences.',
  };

  /// How the quiz questions should read.
  String get quizLevel => switch (this) {
    AgeBand.ages3to5 =>
      'Use very short questions and answers with words a 4-year-old knows.',
    AgeBand.ages6to8 => 'Use short, simple words a 6-year-old can read.',
    AgeBand.ages9to10 => 'Use clear words a 9-year-old reads easily.',
  };

  /// Whether this child sees the Spooky feeling. Too much for the youngest.
  bool get allowsSpooky => this != AgeBand.ages3to5;
}

/// The age band of the child using the app right now.
///
/// One module-level value rather than an argument threaded through the story
/// reader and the reading module's quiz hooks: everything Gemini writes
/// (stories and quizzes, in `story_generator.dart`) reads it, so none of those
/// screens or their test fakes had to change. Safe because one child at a time
/// uses a device. The child dashboard sets it when a child opens it.
class ReaderAudience {
  const ReaderAudience._();

  static AgeBand current = AgeBand.fallback;
}
