/**
 * One random stream per subsystem, so a change in one never shifts another.
 * Never reorder or reuse a number: it would change every saved seed.
 */
export const RNG_STREAMS = {
  map: 0,
  waves: 1,
} as const;
