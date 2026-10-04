/**
 * Seeded pseudo-random numbers for the simulation (mulberry32).
 *
 * All randomness in `src/sim` goes through this module, never `Math.random`.
 * The same seed gives the same sequence on every machine, so a run replays
 * exactly from its seed and its commands.
 *
 * Use one generator per subsystem (map generation, wave composition, ...),
 * each made with `deriveRng(runSeed, stream)`. A single shared generator
 * would shift every later draw whenever one subsystem draws once more, and
 * would change every seed's outcome after an unrelated code change.
 *
 * The state is kept wrapped to 32 bits, which is the correct mulberry32. The
 * widely copied reference snippet keeps a float accumulator and stops
 * matching after about 4.9 million draws; do not change this to match it.
 */

const STEP = 0x6d2b79f5;
const UINT32_RANGE = 4294967296;
const GOLDEN_RATIO_32 = 0x9e3779b9;

/** Generator state. Plain data, so it survives JSON and snapshots. */
export interface Rng {
  state: number;
}

/**
 * Creates a generator from an integer seed. The seed is reduced to 32 bits
 * (negatives wrap). Throws on anything that is not a safe integer.
 */
export function createRng(seed: number): Rng {
  if (!Number.isSafeInteger(seed)) {
    throw new RangeError(`Seed must be a safe integer, got ${seed}.`);
  }
  return {state: seed >>> 0};
}

/**
 * Creates an independent generator for one subsystem. The same seed and
 * stream always give the same generator; different streams and seeds give
 * unrelated sequences. `stream` must be a non-negative safe integer.
 */
export function deriveRng(seed: number, stream: number): Rng {
  if (!Number.isSafeInteger(seed)) {
    throw new RangeError(`Seed must be a safe integer, got ${seed}.`);
  }
  if (!Number.isSafeInteger(stream) || stream < 0) {
    throw new RangeError(
      `Stream must be a non-negative safe integer, got ${stream}.`
    );
  }
  // murmur3 finalizer over (seed + stream * golden ratio): nearby seeds and
  // streams land far apart, so their mulberry32 sequences do not overlap.
  let hash = ((seed >>> 0) + Math.imul(stream + 1, GOLDEN_RATIO_32)) >>> 0;
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x85ebca6b);
  hash ^= hash >>> 13;
  hash = Math.imul(hash, 0xc2b2ae35);
  hash ^= hash >>> 16;
  return {state: hash >>> 0};
}

/** Copies a generator; the copy continues the same sequence independently. */
export function cloneRng(rng: Rng): Rng {
  return {state: rng.state};
}

/** Next float in [0, 1). */
export function nextFloat(rng: Rng): number {
  rng.state = (rng.state + STEP) >>> 0;
  let t = rng.state;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / UINT32_RANGE;
}

/**
 * Next integer in [0, maxExclusive). `maxExclusive` must be an integer from 1
 * to 2^32, the most distinct values one draw can produce.
 */
export function nextInt(rng: Rng, maxExclusive: number): number {
  if (
    !Number.isInteger(maxExclusive) ||
    maxExclusive < 1 ||
    maxExclusive > UINT32_RANGE
  ) {
    throw new RangeError(
      `Bound must be an integer from 1 to ${UINT32_RANGE}, got ${maxExclusive}.`
    );
  }
  return Math.floor(nextFloat(rng) * maxExclusive);
}

/**
 * Next float in [min, max). Both bounds must be finite with `min < max`, and
 * the span must be finite. For a span narrower than the floating-point
 * spacing at `max` the result can equal `max`.
 */
export function nextRange(rng: Rng, min: number, max: number): number {
  const span = max - min;
  if (!Number.isFinite(min) || !Number.isFinite(max) || !(min < max)) {
    throw new RangeError(
      `Range must be finite with min < max, got [${min}, ${max}).`
    );
  }
  if (!Number.isFinite(span)) {
    throw new RangeError(`Range span must be finite, got [${min}, ${max}).`);
  }
  return min + nextFloat(rng) * span;
}

/** A random item from a non-empty list. */
export function pick<T>(rng: Rng, items: readonly T[]): T {
  if (items.length === 0) {
    throw new RangeError('Cannot pick from an empty list.');
  }
  return items[nextInt(rng, items.length)] as T;
}
