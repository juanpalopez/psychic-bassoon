/** Board size in cells. */
export const GRID = {cols: 9, rows: 13} as const;

/** Path generation shape, ported from the 2D prototype. */
export const MAP = {
  /** Give up and retry when the path is shorter than rows + this many cells. */
  minExtraCells: 16,
  maxAttempts: 300,
  /** Each straight run down the board is this many cells, plus 0..1 more. */
  minRunDown: 2,
  runDownVariance: 2,
  /** A sideways turn moves at least this many columns. */
  minTurnColumns: 3,
  /** The path starts at least this many columns in from either edge. */
  startMargin: 1,
} as const;

/** Economy and combat constants ported from the 2D prototype. */
export const RULES = {
  /** Fixed simulation rate. Game speed adds ticks, never a bigger tick. */
  tickRate: 30,
  /** A slow frame is clamped to this many seconds before it is simulated. */
  maxFrameSeconds: 0.05,
  /** Fastest game speed the player can pick (1×, 2×, 3×). */
  maxGameSpeed: 3,
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
  /** Clearing a wave pays `waveClearBase + wave * waveClearPerWave`. */
  waveClearBase: 15,
  waveClearPerWave: 2,
  /** Seconds a Quench Coil slow lasts after the last pulse. */
  quenchSlowSeconds: 1.4,
  /** Rivet Mortar shell speed, cells per second. */
  rocketSpeed: 5.5,
  /** Spawn point sits this far above the top row, in cells. */
  spawnOffset: 0.45,
  /** Cell centre offset: a cell's centre is at col + 0.5. */
  cellCentre: 0.5,
  /** Mainline Arc: reach to the next target and damage kept per jump. */
  arcChainRadius: 1.6,
  arcChainFalloff: 0.8,
} as const;
