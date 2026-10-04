/** Board size in cells. */
export const GRID = {cols: 9, rows: 13} as const;

/** Economy and combat constants ported from the 2D prototype. */
export const RULES = {
  startCredits: 180,
  startLives: 20,
  towerLevels: 3,
  /** Share of credits invested that a sale returns. */
  sellRefund: 0.7,
  /** Armor never cuts a hit below this share of its damage. */
  minDamageFraction: 0.25,
  /** Calling a wave early pays `earlyCallBase + wave * earlyCallPerWave`. */
  earlyCallBase: 10,
  earlyCallPerWave: 2,
  /** Seconds a Quench Coil slow lasts after the last pulse. */
  quenchSlowSeconds: 1.4,
  /** Rivet Mortar shell speed, cells per second. */
  rocketSpeed: 5.5,
  /** Mainline Arc: reach to the next target and damage kept per jump. */
  arcChainRadius: 1.6,
  arcChainFalloff: 0.8,
} as const;
