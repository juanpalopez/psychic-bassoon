/**
 * One random stream per subsystem, so a change in one never shifts another.
 * Never reorder or reuse a number: it would change every saved seed.
 */
export const RNG_STREAMS = {
  map: 0,
  waves: 1,
  /** Which route each foe takes when the map has more than one. */
  routes: 2,
  /** Render-only scenery around the board; never affects the game. */
  scenery: 100,
} as const;
