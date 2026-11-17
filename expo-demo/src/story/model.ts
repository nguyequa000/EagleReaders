/**
 * The story flow's data: the hero catalog, the hero a child builds, and the
 * picks carried through the steps. Ported from lib/screens/story/*.dart; the
 * strings stored in Firestore are the same.
 */

export type HeroFeature = 'hero' | 'pose' | 'pet';
export const HERO_FEATURES: HeroFeature[] = ['hero', 'pose', 'pet'];

export type HeroOption = { value: string | null; label: string };

const DIR = 'assets/story/toon';

export const HEROES: HeroOption[] = [
  { value: 'explorer', label: 'Explorer' },
  { value: 'scout', label: 'Scout' },
  { value: 'friend', label: 'Friend' },
  { value: 'pal', label: 'Pal' },
  { value: 'robot', label: 'Robot' },
  { value: 'monster', label: 'Monster' },
];

export const POSES: HeroOption[] = [
  { value: 'idle', label: 'Standing' },
  { value: 'walk1', label: 'Walking' },
  { value: 'run1', label: 'Running' },
  { value: 'jump', label: 'Jumping' },
  { value: 'cheer1', label: 'Cheering' },
  { value: 'wide', label: 'Arms Wide' },
  { value: 'hold', label: 'Holding' },
  { value: 'talk', label: 'Talking' },
  { value: 'think', label: 'Thinking' },
  { value: 'duck', label: 'Hiding' },
];

/** Outfit colours: the swatch a child taps, and the suffix on the picture. */
export const OUTFIT_COLORS: Record<string, string> = {
  '#4E9FD1': 'blue',
  '#5FAE4B': 'green',
  '#E0A62B': 'yellow',
  '#9470D6': 'purple',
  '#DE6FA6': 'pink',
};

export const PET_ASSETS = [
  'assets/story/pets/pip.png',
  'assets/story/pets/bloop.png',
  'assets/story/pets/sunny.png',
  'assets/story/pets/mint.png',
  'assets/story/pets/sky.png',
  'assets/story/pets/berry.png',
  'assets/story/pets/rusty.png',
  'assets/story/pets/snow.png',
  'assets/story/pets/cloud.png',
  'assets/story/pets/shadow.png',
];

export function heroAssetFor(hero: string, pose: string, colorHex?: string | null): string {
  const suffix = colorHex == null ? '' : `-${OUTFIT_COLORS[colorHex] ?? ''}`;
  return `${DIR}/${hero}/${pose}${suffix}.png`;
}

function labelFromAsset(asset: string): string {
  const file = asset.split('/').pop()!.split('.')[0];
  return file[0].toUpperCase() + file.slice(1);
}

export function optionsFor(feature: HeroFeature): HeroOption[] {
  switch (feature) {
    case 'hero':
      return HEROES;
    case 'pose':
      return POSES;
    case 'pet':
      return [{ value: null, label: 'None' }, ...PET_ASSETS.map((a) => ({ value: a, label: labelFromAsset(a) }))];
  }
}

export function colorsFor(feature: HeroFeature): string[] {
  return feature === 'hero' ? Object.keys(OUTFIT_COLORS) : [];
}

export function featureLabel(feature: HeroFeature): string {
  return feature === 'hero' ? 'Hero' : feature === 'pose' ? 'Pose' : 'Pet';
}

/** Everything a child chose about their hero, as plain strings. */
export type HeroConfig = {
  character?: string | null;
  pose?: string | null;
  outfitColor?: string | null;
  petAsset?: string | null;
  name?: string | null;
};

export const effectiveCharacter = (h: HeroConfig) => h.character ?? HEROES[0].value!;
export const effectivePose = (h: HeroConfig) => h.pose ?? POSES[0].value!;
export const heroAsset = (h: HeroConfig) =>
  heroAssetFor(effectiveCharacter(h), effectivePose(h), h.outfitColor);

export function selectedValue(h: HeroConfig, feature: HeroFeature): string | null {
  return (feature === 'hero' ? h.character : feature === 'pose' ? h.pose : h.petAsset) ?? null;
}

export function withOption(h: HeroConfig, feature: HeroFeature, value: string | null): HeroConfig {
  switch (feature) {
    case 'hero':
      return value == null ? h : { ...h, character: value };
    case 'pose':
      return value == null ? h : { ...h, pose: value };
    case 'pet':
      return { ...h, petAsset: value };
  }
}

/** A random hero, keeping the name and the pet. */
export function randomized(h: HeroConfig): HeroConfig {
  const pick = <T,>(list: T[]) => list[Math.floor(Math.random() * list.length)];
  return {
    character: pick(HEROES).value,
    pose: pick(POSES).value,
    outfitColor: pick(Object.keys(OUTFIT_COLORS)),
    petAsset: h.petAsset,
    name: h.name,
  };
}

export function heroLabel(h: HeroConfig): string {
  return (HEROES.find((o) => o.value === effectiveCharacter(h)) ?? HEROES[0]).label;
}

/** The child's selections across the steps of the story flow. */
export type StoryConfig = {
  hero: HeroConfig;
  mood?: string | null;
  setting?: string | null;
  /** What the child typed on the summary for the AI to build on. */
  idea: string;
};

export const emptyConfig: StoryConfig = { hero: {}, idea: '' };

export type StoryOption = { label: string; asset: string };

export const MOODS: StoryOption[] = [
  { label: 'Funny', asset: 'assets/story/moods/funny.svg' },
  { label: 'Adventurous', asset: 'assets/story/moods/adventurous.svg' },
  { label: 'Spooky', asset: 'assets/story/moods/spooky.svg' },
  { label: 'Calm', asset: 'assets/story/moods/calm.svg' },
];

export const SETTINGS: StoryOption[] = [
  { label: 'Forest', asset: 'assets/story/settings/forest.svg' },
  { label: 'Ocean', asset: 'assets/story/settings/ocean.svg' },
  { label: 'City', asset: 'assets/story/settings/city.svg' },
  { label: 'Outer Space', asset: 'assets/story/settings/space.svg' },
];

export function optionByLabel(options: StoryOption[], label?: string | null): StoryOption | null {
  return label ? options.find((o) => o.label === label) ?? null : null;
}

/** What the store keeps to rebuild a story's config later. */
export function storyConfigToMap(c: StoryConfig): Record<string, any> {
  return {
    character: c.hero.character ?? null,
    pose: c.hero.pose ?? null,
    outfitColor: c.hero.outfitColor ?? null,
    petAsset: c.hero.petAsset ?? null,
    name: c.hero.name ?? null,
    mood: c.mood ?? null,
    setting: c.setting ?? null,
    idea: c.idea,
  };
}

export function storyConfigFromMap(m: Record<string, any>): StoryConfig {
  const s = (v: unknown) => (typeof v === 'string' ? v : null);
  return {
    hero: {
      character: s(m.character),
      pose: s(m.pose),
      outfitColor: s(m.outfitColor),
      petAsset: s(m.petAsset),
      name: s(m.name),
    },
    mood: s(m.mood),
    setting: s(m.setting),
    idea: s(m.idea) ?? '',
  };
}

/** A parent-readable name for a story, e.g. "Robin in Outer Space". */
export function storyTitle(config: StoryConfig): string {
  const named = config.hero.name?.trim();
  const who = named ? named : heroLabel(config.hero);
  return config.setting ? `${who} in ${config.setting}` : who;
}
