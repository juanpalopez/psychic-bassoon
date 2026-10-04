import {RULES, TOWERS, WAVES} from '../content';
import type {TowerDef, TowerId} from '../content';
import {TOWER_IDS} from '../content';
import type {GameEvent, GameState} from '../sim';
import type {Selection} from './selection';

export interface Stat {
  readonly label: string;
  readonly value: string;
  /** The value at the next level, if there is one. */
  readonly next?: string;
}

export interface BuildOption {
  readonly id: TowerId;
  readonly name: string;
  readonly cost: number;
  readonly affordable: boolean;
  readonly description: string;
}

export type PanelModel =
  | {readonly kind: 'hint'}
  | {readonly kind: 'build'; readonly options: readonly BuildOption[]}
  | {
      readonly kind: 'tower';
      readonly id: TowerId;
      readonly name: string;
      /** 1 to 3. */
      readonly level: number;
      readonly stats: readonly Stat[];
      /** Undefined at the top level. */
      readonly upgrade:
        {readonly cost: number; readonly affordable: boolean} | undefined;
      readonly sell: number;
    };

/** Everything the HUD shows, as plain data, so it can be tested. */
export interface HudModel {
  readonly credits: number;
  readonly lives: number;
  readonly wave: number;
  readonly best: number;
  readonly lowLives: boolean;
  readonly over: boolean;
  readonly launch: {readonly label: string; readonly enabled: boolean};
  readonly panel: PanelModel;
}

const LOW_LIVES = 5;

const DESCRIPTIONS: Readonly<Record<TowerId, string>> = {
  welder: 'Fast single target',
  rivetMortar: 'Splash damage',
  quenchCoil: 'Slows all in range',
  mainlineArc: 'Chain lightning',
};

const fixed = (digits: number) => (v: number) => v.toFixed(digits);
const whole = (v: number) => String(Math.round(v));
const percent = (v: number) => `${Math.round(v * 100)}%`;

function stat(
  label: string,
  values: readonly number[],
  level: number,
  format: (v: number) => string
): Stat {
  const value = format(values[level] ?? 0);
  const next = values[level + 1];
  return next === undefined
    ? {label, value}
    : {label, value, next: format(next)};
}

function towerStats(def: TowerDef, id: TowerId, level: number): Stat[] {
  const dps = def.damage.map((d, i) => d * (def.rate[i] ?? 0));
  const special =
    id === 'rivetMortar'
      ? stat('Splash', def.splash ?? [], level, fixed(1))
      : id === 'quenchCoil'
        ? stat('Slow', def.slow ?? [], level, percent)
        : id === 'mainlineArc'
          ? stat('Chain', def.chain ?? [], level, whole)
          : stat('DPS', dps, level, whole);
  return [
    stat('Dmg', def.damage, level, whole),
    stat('Range', def.range, level, fixed(1)),
    stat('Rate/s', def.rate, level, fixed(1)),
    special,
  ];
}

function panelModel(game: GameState, selection: Selection): PanelModel {
  if (selection.kind === 'plate') {
    return {
      kind: 'build',
      options: TOWER_IDS.map(id => ({
        id,
        name: TOWERS[id].name,
        cost: TOWERS[id].cost[0],
        affordable: game.credits >= TOWERS[id].cost[0],
        description: DESCRIPTIONS[id],
      })),
    };
  }
  if (selection.kind === 'tower') {
    const tower = game.towers.find(t => t.id === selection.id);
    if (tower) {
      const def = TOWERS[tower.type];
      const nextCost = def.cost[tower.level + 1];
      return {
        kind: 'tower',
        id: tower.type,
        name: def.name,
        level: tower.level + 1,
        stats: towerStats(def, tower.type, tower.level),
        upgrade:
          nextCost === undefined
            ? undefined
            : {cost: nextCost, affordable: game.credits >= nextCost},
        sell: Math.floor(tower.invested * RULES.sellRefund),
      };
    }
  }
  return {kind: 'hint'};
}

function launchModel(game: GameState): HudModel['launch'] {
  if (game.over) return {label: 'Core breached', enabled: false};
  if (!game.running) {
    return {label: `Launch wave ${game.wave + 1}`, enabled: true};
  }
  if (game.spawners.length > 0) {
    return {label: `Wave ${game.wave} incoming`, enabled: false};
  }
  const bonus = RULES.earlyCallBase + game.wave * RULES.earlyCallPerWave;
  return {label: `Call wave ${game.wave + 1} · +${bonus}`, enabled: true};
}

export function hudModel(
  game: GameState,
  selection: Selection,
  best: number
): HudModel {
  return {
    credits: game.credits,
    lives: game.lives,
    wave: game.wave,
    best,
    lowLives: game.lives <= LOW_LIVES,
    over: game.over,
    launch: launchModel(game),
    panel: panelModel(game, selection),
  };
}

const REJECTIONS: Readonly<Record<string, string>> = {
  notEnoughCredits: 'Not enough credits',
  occupied: 'Plate already in use',
  notAPlate: 'Build on a metal plate',
  maxLevel: 'Already max level',
  waveInProgress: 'Wave still incoming',
};

/** Short message for an event the player should notice, or undefined. */
export function toastFor(event: GameEvent): string | undefined {
  switch (event.type) {
    case 'waveCleared':
      return `Wave ${event.wave} cleared +${event.bonus}`;
    case 'waveLaunched':
      if (event.earlyBonus > 0) return `Early call +${event.earlyBonus}`;
      if (event.wave % WAVES.bossEvery === 0) {
        return `Wave ${event.wave}: Overseer incoming`;
      }
      if (event.wave % WAVES.swarmEvery === 0) {
        return `Wave ${event.wave}: Skitter swarm`;
      }
      return undefined;
    case 'commandRejected':
      return REJECTIONS[event.reason];
    default:
      return undefined;
  }
}
