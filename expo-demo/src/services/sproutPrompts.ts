import { SPROUT_PROMPTS } from './sproutPromptData';

/** Which part of the story a Sprout idea is for. */
export type StoryStage = 'beginning' | 'middle' | 'end' | 'any';

/** One idea question; may contain {character}, {setting} and {mood}. */
export type SproutPrompt = {
  text: string;
  stage: StoryStage;
  characters: string[];
  settings: string[];
  moods: string[];
};

/**
 * Everything Sprout is allowed to know: the child's three picks and the part
 * of the story they're on. Never the child's text — that rule is what keeps
 * Sprout safe to put next to a text field.
 */
export type SproutRequest = {
  character: string;
  setting?: string | null;
  mood?: string | null;
  stage: StoryStage;
};

const isTagged = (p: SproutPrompt) => p.characters.length > 0 || p.settings.length > 0 || p.moods.length > 0;

function fits(p: SproutPrompt, r: SproutRequest): boolean {
  return (
    (p.stage === 'any' || r.stage === 'any' || p.stage === r.stage) &&
    (p.characters.length === 0 || p.characters.includes(r.character)) &&
    (p.settings.length === 0 || (r.setting != null && p.settings.includes(r.setting))) &&
    (p.moods.length === 0 || (r.mood != null && p.moods.includes(r.mood)))
  );
}

export const FALLBACK_IDEA = 'What happens next?';

export function characterPhrase(character: string): string {
  return `the ${character.toLowerCase()}`;
}

function settingPhrase(setting?: string | null): string {
  if (!setting) return 'this place';
  const lower = setting.toLowerCase();
  return lower === 'outer space' ? lower : `the ${lower}`;
}

function fill(text: string, r: SproutRequest): string {
  return text
    .replace(/\{character\}/g, characterPhrase(r.character))
    .replace(/\{setting\}/g, settingPhrase(r.setting))
    .replace(/\{mood\}/g, (r.mood ?? 'happy').toLowerCase());
}

/**
 * The offline prompt bank: no network, no model, just questions picked to fit
 * the child's choices. A prompt only comes back once every other match has had
 * its turn.
 */
export class LocalSproutIdeas {
  private shown = new Map<StoryStage, Set<SproutPrompt>>();

  nextIdea(request: SproutRequest): string {
    const matches = SPROUT_PROMPTS.filter((p) => fits(p, request));
    if (matches.length === 0) return FALLBACK_IDEA;
    let shown = this.shown.get(request.stage);
    if (!shown) this.shown.set(request.stage, (shown = new Set()));
    let fresh = matches.filter((p) => !shown!.has(p));
    if (fresh.length === 0) {
      matches.forEach((p) => shown!.delete(p));
      fresh = matches;
    }
    // Ideas made for these picks first; the generic ones once those run out.
    const tagged = fresh.filter(isTagged);
    const pool = tagged.length ? tagged : fresh;
    const prompt = pool[Math.floor(Math.random() * pool.length)];
    shown.add(prompt);
    const text = fill(prompt.text, request).trim();
    return text || FALLBACK_IDEA;
  }
}

/** The hint under each guided heading. */
export function stageHint(stage: StoryStage, character: string): string {
  switch (stage) {
    case 'beginning':
      return 'Who is your story about? Where are they?';
    case 'middle':
      return 'What surprise or problem happens?';
    default:
      return `How does it end? How does ${character} feel?`;
  }
}
