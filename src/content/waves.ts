/** Wave composition and per-wave scaling, ported from the 2D prototype. */
export const WAVES = {
  bossEvery: 10,
  swarmEvery: 5,
  /** Robots in wave w: round(baseCount + w * countPerWave). */
  baseCount: 6,
  countPerWave: 1.4,
  /** Seconds before the first robot of a wave. */
  firstSpawnDelay: 0.2,

  /** Base gap in seconds: max(gapMin, gapBase - w * gapPerWave). */
  gapBase: 0.95,
  gapPerWave: 0.025,
  gapMin: 0.32,
  /** Gap after a robot, as a multiple of the base gap. */
  gapMultiplier: {
    hauler: 1,
    smelter: 1.4,
    skitter: 0.6,
    skitterSwarm: 0.45,
    bossEscort: 2,
  },
  /** Gap in seconds after the Overseer. */
  overseerGap: 1,

  /** Swarm waves: share of Skitters, the rest are Haulers. */
  swarmSkitterChance: 0.75,
  /** Normal waves: Skitters from this wave on, with this chance. */
  skitterFromWave: 2,
  skitterChance: 0.3,
  /** Smelters from this wave on when the roll beats the threshold. */
  smelterFromWave: 4,
  smelterBaseThreshold: 0.82,
  smelterThresholdPerWave: 0.01,
  smelterThresholdCap: 0.2,

  /** hp multiplier: 1 + hpLinear * (w - 1) + hpQuadratic * (w - 1)^2. */
  hpLinear: 0.2,
  hpQuadratic: 0.014,
  /** Speed multiplier: 1 + min(speedCap, w * speedPerWave). */
  speedPerWave: 0.006,
  speedCap: 0.25,
  /** Reward multiplier: 1 + rewardPerWave * (w - 1). */
  rewardPerWave: 0.04,
  /** Extra armor point every this many waves. */
  armorEveryWaves: 12,
} as const;
