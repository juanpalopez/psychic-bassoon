export interface EnemyDef {
  readonly name: string;
  readonly hp: number;
  /** Cells per second. */
  readonly speed: number;
  /** Credits paid when destroyed. */
  readonly reward: number;
  readonly armor: number;
  /** Body radius, in cells. */
  readonly radius: number;
  /** Lives lost when it reaches the Core. */
  readonly leak: number;
}

export const ENEMY_IDS = ['skitter', 'hauler', 'smelter', 'overseer'] as const;

export type EnemyId = (typeof ENEMY_IDS)[number];

/** Numbers ported from the 2D prototype's `EN` table. */
export const ENEMIES: Readonly<Record<EnemyId, EnemyDef>> = {
  skitter: {
    name: 'Skitter',
    hp: 20,
    speed: 1.9,
    reward: 4,
    armor: 0,
    radius: 0.24,
    leak: 1,
  },
  hauler: {
    name: 'Hauler',
    hp: 42,
    speed: 1.15,
    reward: 6,
    armor: 0,
    radius: 0.3,
    leak: 1,
  },
  smelter: {
    name: 'Smelter',
    hp: 130,
    speed: 0.68,
    reward: 13,
    armor: 4,
    radius: 0.38,
    leak: 2,
  },
  overseer: {
    name: 'Overseer',
    hp: 850,
    speed: 0.5,
    reward: 110,
    armor: 6,
    radius: 0.5,
    leak: 6,
  },
};
