/** The part of `localStorage` the game uses, so tests can fake it. */
export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

/** Same key as the 2D prototype, so an old best carries over. */
const BEST_KEY = 'scrapline-best';

export function loadBest(store: KeyValueStore): number {
  try {
    const value = Number(store.getItem(BEST_KEY));
    return Number.isInteger(value) && value > 0 ? value : 0;
  } catch {
    return 0;
  }
}

/** Stores `wave` if it beats `best`; returns the new best. Never throws. */
export function saveBest(
  store: KeyValueStore,
  best: number,
  wave: number
): number {
  if (wave <= best) return best;
  try {
    store.setItem(BEST_KEY, String(wave));
  } catch {
    // storage is blocked: keep the best for this session only
  }
  return wave;
}
