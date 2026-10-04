/** Level-indexed stats: index 0 is level 1, index 2 is level 3. */
export type PerLevel = readonly [number, number, number];

export interface TowerDef {
  readonly name: string;
  readonly cost: PerLevel;
  readonly damage: PerLevel;
  readonly range: PerLevel;
  /** Shots per second. */
  readonly rate: PerLevel;
  /** Rivet Mortar blast radius, in cells. */
  readonly splash?: PerLevel;
  /** Quench Coil speed reduction, 0..1. */
  readonly slow?: PerLevel;
  /** Mainline Arc number of targets hit. */
  readonly chain?: PerLevel;
}

export const TOWER_IDS = [
  'welder',
  'rivetMortar',
  'quenchCoil',
  'mainlineArc',
] as const;

export type TowerId = (typeof TOWER_IDS)[number];

/** Numbers ported from the 2D prototype's `DEF` table. */
export const TOWERS: Readonly<Record<TowerId, TowerDef>> = {
  welder: {
    name: 'Welder',
    cost: [50, 60, 110],
    damage: [9, 15, 26],
    range: [2.3, 2.6, 3.0],
    rate: [3, 3.6, 4.5],
  },
  rivetMortar: {
    name: 'Rivet Mortar',
    cost: [90, 90, 160],
    damage: [32, 56, 96],
    range: [2.8, 3.1, 3.5],
    rate: [0.7, 0.8, 0.95],
    splash: [0.95, 1.15, 1.35],
  },
  quenchCoil: {
    name: 'Quench Coil',
    cost: [70, 70, 120],
    damage: [3, 5, 9],
    range: [1.7, 2.0, 2.4],
    rate: [1, 1.15, 1.35],
    slow: [0.35, 0.45, 0.55],
  },
  mainlineArc: {
    name: 'Mainline Arc',
    cost: [110, 100, 180],
    damage: [18, 30, 50],
    range: [2.3, 2.6, 2.9],
    rate: [0.9, 1.1, 1.3],
    chain: [3, 4, 6],
  },
};
