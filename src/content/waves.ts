/** Wave composition and per-wave scaling, ported from the 2D prototype. */
export const WAVES = {
  bossEvery: 10,
  swarmEvery: 5,
  /** Foes in wave w: round(baseCount + w * countPerWave). */
  baseCount: 6,
  countPerWave: 1.4,
  /** Seconds before the first foe of a wave. */
  firstSpawnDelay: 0.2,

  /** Base gap in seconds: max(gapMin, gapBase - w * gapPerWave). */
  gapBase: 0.95,
  gapPerWave: 0.025,
  gapMin: 0.32,
  /** Gap after a foe, as a multiple of the base gap. */
  gapMultiplier: {
    raider: 1,
    ironclad: 1.4,
    scamp: 0.6,
    scampSwarm: 0.45,
    bossEscort: 2,
  },
  /** Gap in seconds after the Warlord. */
  warlordGap: 1,

  /** Swarm waves: share of Scamps, the rest are Raiders. */
  swarmScampChance: 0.75,
  /** Normal waves: Scamps from this wave on, with this chance. */
  scampFromWave: 2,
  scampChance: 0.3,
  /** Ironclads from this wave on when the roll beats the threshold. */
  ironcladFromWave: 4,
  ironcladBaseThreshold: 0.82,
  ironcladThresholdPerWave: 0.01,
  ironcladThresholdCap: 0.2,

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
