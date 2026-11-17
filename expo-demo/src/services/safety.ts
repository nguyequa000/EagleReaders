/**
 * The child-safety checks on everything a child types before it reaches
 * Gemini, ported from lib/services/story_generator.dart: personal details
 * are scrubbed, self-harm or abuse stops the story for a grown-up, and
 * swearing and slurs are refused.
 */

// Kids' stories never need real contact details; scrub them before any model
// sees the prompt.
const PII_PATTERNS = [
  /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g,
  /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/g,
  /\b\d{3}[-.\s]\d{4}\b/g,
  /\b\d{1,5}(?:[ \t]+[A-Za-z]+){1,3}[ \t]+(?:street|st|avenue|ave|road|rd|lane|ln|drive)\b/gi,
  // Capitalised name only, so "go to school" is left alone.
  /\b[A-Z]\w*[ \t]+(?:School|Elementary|Academy)\b/g,
];

export function redactPII(s: string): string {
  return PII_PATTERNS.reduce((text, pattern) => text.replace(pattern, '[removed]'), s);
}

const GROWN_UP_TERMS = new RegExp(
  String.raw`\b(?:kill(?:ing)? my ?self|kms|suicide|hurt(?:ing)? my ?self|` +
    String.raw`self[-\s]?harm|cutting my ?self|want to die|wanna die|` +
    String.raw`don'?t want to (?:live|be alive)|abus(?:e|ed|es|ing)|` +
    String.raw`(?:hits?|hurts?|hurting|touche[sd]) me)\b`,
  'i',
);

/** True when [s] mentions self-harm or abuse and a grown-up should step in. */
export function needsGrownUp(s: string): boolean {
  return GROWN_UP_TERMS.test(s);
}

const BAD_WORDS = new RegExp(
  String.raw`\b(?:` +
    // swearing
    String.raw`f+u+c+k+\w*|fck\w*|fuk\w*|fuq\w*|fk|fking|fkn|frick\w*|frig\w*|` +
    String.raw`motherf\w*|mf|mofo|sh+i+t+\w*|sht|shiz\w*|bullshit|bs|biatch|beyotch|` +
    String.raw`azz|screw (?:you|u)|suck my \w+|stupid bitch|` +
    // Kid words like cockatoo, prickly, arsenal, Dickens stay allowed.
    String.raw`ass|asses|asshole\w*|arse|arsehole\w*|jackass|dumbass|bitch\w*|` +
    String.raw`bastard\w*|damn\w*|goddamn\w*|hell|crap\w*|piss\w*|dick|dicks|` +
    String.raw`dickhead\w*|cock|cocks|cocksuck\w*|pussy|pussies|cunt\w*|twat\w*|` +
    String.raw`wank\w*|bollocks|prick|pricks|slut\w*|whore\w*|hoe|hoes|` +
    String.raw`boob\w*|tits?|titties|penis\w*|vagina\w*|porn\w*|sex\w*|horny|nude\w*|` +
    String.raw`dildo\w*|cum|jizz|stfu|wtf|omfg|` +
    // telling someone to hurt themselves / threats
    String.raw`kys|kms|kill (?:your|ur|yo|you) ?sel(?:f|ves)|(?:you|u) should die|` +
    String.raw`(?:go|just) kill (?:your|ur) ?self|kill (?:yo)?u|kill urself|` +
    String.raw`(?:hang|neck|cut|hurt|shoot|end) (?:your|ur) ?sel(?:f|ves)|unalive\w*|` +
    String.raw`go die|(?:i hope|hope) (?:you|u) die|drop dead|i(?:ll| will) kill (?:you|u)|` +
    // slurs and hate words
    String.raw`nigg\w*|nigga\w*|negro\w*|chink\w*|gook\w*|spic|spics|wetback\w*|` +
    String.raw`kike\w*|beaner\w*|coon|coons|raghead\w*|towelhead\w*|paki|pakis|` +
    String.raw`jap|japs|gypsy|gyp|redskin\w*|tranny|trannies|fag\w*|dyke\w*|` +
    String.raw`retard\w*|spaz\w*|nazi\w*|hitler|kkk` +
    String.raw`)\b`,
  'i',
);

// Strong words never part of a normal word, found even when glued into
// other text ("youfuckingidiot", "killurself").
const HIDDEN_WORDS = new RegExp(
  String.raw`fuck|fuk|fuq|shit|cunt|bitch|nigg|fagot|faggot|motherf|asshole|` +
    String.raw`kil+(?:yo)?u?r?sel(?:f|ves)|kys(?:now|plz|pls)|hopeyoudie|godie\b`,
);

const LEET: [string, string][] = [
  ['@', 'a'],
  ['$', 's'],
  ['0', 'o'],
  ['1', 'i'],
  ['!', 'i'],
  ['|', 'i'],
  ['3', 'e'],
  ['4', 'a'],
  ['5', 's'],
  ['7', 't'],
  ['8', 'b'],
  ['9', 'g'],
  ['+', 't'],
  ['*', 'u'],
  ['ph', 'f'],
];

/** True when [s] has swearing, slurs or other words not for a kids' story. */
export function hasBadWords(s: string): boolean {
  let plain = s.toLowerCase();
  for (const [from, to] of LEET) plain = plain.split(from).join(to);
  // "f u c k", "f.u.c.k", "s-h-i-t" -> one word.
  const joined = plain.replace(/\b(?:[a-z][\s.\-_,]+){2,}[a-z]\b/g, (m) => m.replace(/[^a-z]/g, ''));
  // "fuuuck" -> "fuck" (kept separate: "ass" needs its ss).
  const squeezed = joined.replace(/([a-z])\1+/g, '$1');
  return (
    [s, plain, joined, squeezed].some((t) => BAD_WORDS.test(t)) ||
    HIDDEN_WORDS.test(squeezed.replace(/[^a-z]/g, ''))
  );
}

export const BAD_WORDS_MESSAGE = "Let's use kind words in our story!";
