import 'sprout_prompts.dart';

/// Sprout's idea bank.
///
/// In Dart rather than a JSON asset so the rules below are checked at test
/// time against the real list (`test/sprout_prompts_test.dart`):
/// - every prompt is a question and ends with `?`
/// - at most 12 words, simple words for ages 3–10
/// - kind and gentle, even the Spooky ones: nothing scary, violent or sad
/// - no real names, brands, links or numbers
/// - it asks, it never tells
///
/// Tags use the hero keys from `HeroCatalog.heroes` and the setting and mood
/// labels from `StoryOptions`. Every option needs a few tagged prompts.
const List<SproutPrompt> kSproutPrompts = <SproutPrompt>[
  // Beginning, any picks.
  SproutPrompt(
    'Who is {character}? What do they look like?',
    stage: StoryStage.beginning,
  ),
  SproutPrompt('Where does {character} live?', stage: StoryStage.beginning),
  SproutPrompt('What does {setting} look like?', stage: StoryStage.beginning),
  SproutPrompt(
    'What does {character} like to do?',
    stage: StoryStage.beginning,
  ),
  SproutPrompt(
    'What sounds can you hear in {setting}?',
    stage: StoryStage.beginning,
  ),
  SproutPrompt(
    "Who is {character}'s best friend?",
    stage: StoryStage.beginning,
  ),
  SproutPrompt(
    'What is {character} doing when the story starts?',
    stage: StoryStage.beginning,
  ),
  SproutPrompt('What does {setting} smell like?', stage: StoryStage.beginning),

  // Middle, any picks.
  SproutPrompt(
    'What surprise does {character} find?',
    stage: StoryStage.middle,
  ),
  SproutPrompt('Who does {character} meet?', stage: StoryStage.middle),
  SproutPrompt('What problem does {character} have?', stage: StoryStage.middle),
  SproutPrompt(
    'What does {character} want to do next?',
    stage: StoryStage.middle,
  ),
  SproutPrompt('Who could help {character}?', stage: StoryStage.middle),
  SproutPrompt('What does {character} say?', stage: StoryStage.middle),
  SproutPrompt(
    'What happens when {character} looks around?',
    stage: StoryStage.middle,
  ),
  SproutPrompt('How does {character} feel now? Why?', stage: StoryStage.middle),

  // End, any picks.
  SproutPrompt('How does {character} fix the problem?', stage: StoryStage.end),
  SproutPrompt('How does {character} feel at the end?', stage: StoryStage.end),
  SproutPrompt('What did {character} learn?', stage: StoryStage.end),
  SproutPrompt(
    "Where does {character} go when it's all over?",
    stage: StoryStage.end,
  ),
  SproutPrompt(
    "What is the best part of {character}'s day?",
    stage: StoryStage.end,
  ),
  SproutPrompt('What would {character} do tomorrow?', stage: StoryStage.end),

  // Heroes.
  SproutPrompt(
    'What is {character} hoping to discover?',
    stage: StoryStage.beginning,
    characters: {'explorer'},
  ),
  SproutPrompt(
    'What does {character} pack in their bag?',
    stage: StoryStage.beginning,
    characters: {'explorer'},
  ),
  SproutPrompt(
    'Which path does {character} choose to follow?',
    stage: StoryStage.middle,
    characters: {'explorer'},
  ),
  SproutPrompt(
    'What is {character} looking out for today?',
    stage: StoryStage.beginning,
    characters: {'scout'},
  ),
  SproutPrompt(
    'What clue does {character} spot first?',
    stage: StoryStage.middle,
    characters: {'scout'},
  ),
  SproutPrompt(
    'How does {character} help someone along the way?',
    characters: {'scout'},
  ),
  SproutPrompt(
    'Who does {character} want to make smile today?',
    stage: StoryStage.beginning,
    characters: {'friend'},
  ),
  SproutPrompt(
    'How does {character} show they care?',
    stage: StoryStage.middle,
    characters: {'friend'},
  ),
  SproutPrompt(
    'What does {character} share with a new friend?',
    characters: {'friend'},
  ),
  SproutPrompt(
    'What game does {character} love to play?',
    stage: StoryStage.beginning,
    characters: {'pal'},
  ),
  SproutPrompt(
    'Who does {character} invite along?',
    stage: StoryStage.middle,
    characters: {'pal'},
  ),
  SproutPrompt('What makes {character} laugh out loud?', characters: {'pal'}),
  SproutPrompt(
    'What job was {character} built to do?',
    stage: StoryStage.beginning,
    characters: {'robot'},
  ),
  SproutPrompt(
    'What sound does {character} make when it is happy?',
    characters: {'robot'},
  ),
  SproutPrompt(
    'What new thing does {character} learn about people?',
    stage: StoryStage.end,
    characters: {'robot'},
  ),
  SproutPrompt(
    'What color is {character}? Is it fuzzy?',
    stage: StoryStage.beginning,
    characters: {'monster'},
  ),
  SproutPrompt(
    'What snack does {character} like best?',
    characters: {'monster'},
  ),
  SproutPrompt(
    'How does {character} show everyone it is friendly?',
    stage: StoryStage.middle,
    characters: {'monster'},
  ),

  // Places.
  SproutPrompt(
    'Which animals live near {character} in the forest?',
    settings: {'Forest'},
  ),
  SproutPrompt(
    'What does {character} find behind the tallest tree?',
    stage: StoryStage.middle,
    settings: {'Forest'},
  ),
  SproutPrompt(
    'What is growing on the forest floor?',
    stage: StoryStage.beginning,
    settings: {'Forest'},
  ),
  SproutPrompt(
    'What does {character} see under the water?',
    stage: StoryStage.middle,
    settings: {'Ocean'},
  ),
  SproutPrompt(
    'Which sea creature swims up to say hello?',
    settings: {'Ocean'},
  ),
  SproutPrompt(
    'Is {character} on a boat, a beach, or an island?',
    stage: StoryStage.beginning,
    settings: {'Ocean'},
  ),
  SproutPrompt(
    'What does {character} see from a tall building?',
    settings: {'City'},
  ),
  SproutPrompt(
    'Who does {character} meet on a busy street?',
    stage: StoryStage.middle,
    settings: {'City'},
  ),
  SproutPrompt(
    'What is the city like at night?',
    stage: StoryStage.beginning,
    settings: {'City'},
  ),
  SproutPrompt(
    'What does {character} see out the rocket window?',
    settings: {'Outer Space'},
  ),
  SproutPrompt(
    'Which planet does {character} visit?',
    stage: StoryStage.middle,
    settings: {'Outer Space'},
  ),
  SproutPrompt(
    'What does it feel like to float in space?',
    stage: StoryStage.beginning,
    settings: {'Outer Space'},
  ),

  // Feelings.
  SproutPrompt('What silly thing happens to {character}?', moods: {'Funny'}),
  SproutPrompt(
    'What joke does {character} tell?',
    stage: StoryStage.middle,
    moods: {'Funny'},
  ),
  SproutPrompt(
    'What makes everyone giggle at the end?',
    stage: StoryStage.end,
    moods: {'Funny'},
  ),
  SproutPrompt('What makes {character} feel so brave?', moods: {'Adventurous'}),
  SproutPrompt(
    'What big adventure is {character} starting?',
    stage: StoryStage.beginning,
    moods: {'Adventurous'},
  ),
  SproutPrompt(
    'What treasure does {character} hope to find?',
    stage: StoryStage.middle,
    moods: {'Adventurous'},
  ),
  // Spooky stays gentle: shadows and noises that turn out to be friends.
  SproutPrompt(
    'What makes a funny noise in the dark?',
    stage: StoryStage.middle,
    moods: {'Spooky'},
  ),
  SproutPrompt(
    'Whose shadow is that? Is it a friend?',
    stage: StoryStage.middle,
    moods: {'Spooky'},
  ),
  SproutPrompt(
    'What does {character} find inside the old, creaky house?',
    moods: {'Spooky'},
  ),
  SproutPrompt(
    'What turns out to be not spooky at all?',
    stage: StoryStage.end,
    moods: {'Spooky'},
  ),
  SproutPrompt('What helps {character} feel cozy and calm?', moods: {'Calm'}),
  SproutPrompt(
    'What quiet thing does {character} notice?',
    stage: StoryStage.middle,
    moods: {'Calm'},
  ),
  SproutPrompt(
    'Where does {character} rest at the end of the day?',
    stage: StoryStage.end,
    moods: {'Calm'},
  ),
];
