import {GRID, RULES, TOWERS} from '../../content';
import type {EnemyId, TowerId} from '../../content';
import {stepCombat} from '../combat';
import {buildRoute, generateMap} from '../map';
import type {GameMap, Route} from '../map';
import {deriveRng} from '../rng';
import type {Rng} from '../rng';
import {RNG_STREAMS} from '../streams';
import {settleWave, startWave, stepSpawners} from '../waves';

/** A tower on a plot. `level` counts from 0 (level 1) to 2 (level 3). */
export interface Tower {
  readonly id: number;
  readonly type: TowerId;
  level: number;
  readonly col: number;
  readonly row: number;
  /** Gold spent so far; a sale refunds a share of it. */
  invested: number;
  /** Seconds until it may fire again. Runs below zero while idle. */
  cooldown: number;
}

/** A foe walking the route. Removed from the game when `alive` is false. */
export interface Enemy {
  readonly id: number;
  readonly type: EnemyId;
  hp: number;
  readonly maxHp: number;
  /** Cells per second before any slow. */
  speed: number;
  readonly reward: number;
  armor: number;
  readonly radius: number;
  readonly leak: number;
  /** Index into `GameState.routes` of the route this foe walks. */
  readonly route: number;
  /** Cells walked from the spawn point. */
  distance: number;
  x: number;
  y: number;
  /** Share of speed lost, 0..1, while `slowTimer` runs. */
  slow: number;
  slowTimer: number;
  alive: boolean;
}

/** One foe a wave will release, and the pause before the next one. */
export interface SpawnOrder {
  readonly type: EnemyId;
  readonly gap: number;
}

/** A wave releasing its foes over time. */
export interface Spawner {
  queue: SpawnOrder[];
  /** Seconds until the next release. */
  timer: number;
  readonly wave: number;
}

/** A Catapult shell in flight. */
export interface Shot {
  x: number;
  y: number;
  readonly targetId: number;
  /** Where the target was last seen; the shell keeps going there. */
  targetX: number;
  targetY: number;
  readonly damage: number;
  readonly splash: number;
}

/**
 * Player actions. They are the only way in: state changes through commands
 * and ticks, nothing else.
 */
export type Command =
  | {
      readonly type: 'build';
      readonly tower: TowerId;
      readonly col: number;
      readonly row: number;
    }
  | {readonly type: 'upgrade'; readonly towerId: number}
  | {readonly type: 'sell'; readonly towerId: number}
  | {readonly type: 'launchWave'};

export type RejectReason =
  | 'gameOver'
  | 'notAPlot'
  | 'unknownTower'
  | 'occupied'
  | 'notEnoughGold'
  | 'maxLevel'
  | 'noSuchTower'
  | 'waveInProgress';

/** What happened during the last tick, for render and UI to react to. */
export type GameEvent =
  | {readonly type: 'towerBuilt'; readonly towerId: number}
  | {
      readonly type: 'towerUpgraded';
      readonly towerId: number;
      readonly level: number;
    }
  | {
      readonly type: 'towerSold';
      readonly towerId: number;
      readonly refund: number;
    }
  | {
      readonly type: 'waveLaunched';
      readonly wave: number;
      readonly earlyBonus: number;
    }
  | {
      readonly type: 'waveCleared';
      readonly wave: number;
      readonly bonus: number;
    }
  | {
      readonly type: 'enemySpawned';
      readonly enemyId: number;
      readonly foe: EnemyId;
      readonly wave: number;
    }
  | {
      readonly type: 'enemyKilled';
      readonly enemyId: number;
      readonly foe: EnemyId;
      readonly reward: number;
      readonly x: number;
      readonly y: number;
    }
  | {
      /** A tower fired. `path` is where its shot or bolt went, in order. */
      readonly type: 'towerFired';
      readonly towerId: number;
      readonly tower: TowerId;
      readonly level: number;
      /** The tower's centre. */
      readonly x: number;
      readonly y: number;
      readonly path: readonly {readonly x: number; readonly y: number}[];
    }
  | {
      readonly type: 'shellLanded';
      readonly x: number;
      readonly y: number;
      readonly splash: number;
    }
  | {
      readonly type: 'enemyLeaked';
      readonly enemyId: number;
      readonly leak: number;
    }
  | {readonly type: 'gameOver'; readonly wave: number}
  | {
      readonly type: 'commandRejected';
      readonly command: Command;
      readonly reason: RejectReason;
    };

/**
 * The aggregate root: the whole game as plain data. Only `tick` mutates it,
 * and only after `submit` queued the commands it runs.
 */
export interface GameState {
  readonly seed: number;
  readonly map: GameMap;
  /** The main route (`routes[0]`), built once from the map. */
  readonly route: Route;
  /** Every route from the spawn to the Heartstone; foes pick one. */
  readonly routes: readonly Route[];
  tick: number;
  gold: number;
  lives: number;
  /** Number of the wave most recently launched; 0 before the first. */
  wave: number;
  running: boolean;
  over: boolean;
  towers: Tower[];
  enemies: Enemy[];
  shots: Shot[];
  spawners: Spawner[];
  /** Random stream for wave composition, separate from the map's. */
  rng: Rng;
  /** Random stream that picks which route each foe takes. */
  routeRng: Rng;
  nextId: number;
  /** Commands waiting for the next tick, in submission order. */
  pending: Command[];
  /** Events from the last tick only. */
  events: GameEvent[];
}

export function createGame(seed: number): GameState {
  const map = generateMap(seed);
  return {
    seed,
    map,
    route: buildRoute(map.path),
    routes: map.routes.map(cells => buildRoute(cells)),
    tick: 0,
    gold: RULES.startGold,
    lives: RULES.startLives,
    wave: 0,
    running: false,
    over: false,
    towers: [],
    enemies: [],
    shots: [],
    spawners: [],
    rng: deriveRng(seed, RNG_STREAMS.waves),
    routeRng: deriveRng(seed, RNG_STREAMS.routes),
    nextId: 0,
    pending: [],
    events: [],
  };
}

/** Queues a command for the next tick. Does not change the game itself. */
export function submit(game: GameState, command: Command): void {
  game.pending.push(command);
}

function reject(game: GameState, command: Command, reason: RejectReason) {
  game.events.push({type: 'commandRejected', command, reason});
}

function isPlot(game: GameState, col: number, row: number): boolean {
  return (
    Number.isInteger(col) &&
    Number.isInteger(row) &&
    col >= 0 &&
    col < GRID.cols &&
    row >= 0 &&
    row < GRID.rows &&
    game.map.tiles[row]?.[col] === 'plot'
  );
}

function build(game: GameState, command: Extract<Command, {type: 'build'}>) {
  const {tower, col, row} = command;
  if (!Object.hasOwn(TOWERS, tower))
    return reject(game, command, 'unknownTower');
  if (!isPlot(game, col, row)) return reject(game, command, 'notAPlot');
  if (game.towers.some(t => t.col === col && t.row === row)) {
    return reject(game, command, 'occupied');
  }
  const cost = TOWERS[tower].cost[0];
  if (game.gold < cost) return reject(game, command, 'notEnoughGold');
  game.gold -= cost;
  const id = game.nextId++;
  game.towers.push({
    id,
    type: tower,
    level: 0,
    col,
    row,
    invested: cost,
    cooldown: 0,
  });
  game.events.push({type: 'towerBuilt', towerId: id});
}

function upgrade(
  game: GameState,
  command: Extract<Command, {type: 'upgrade'}>
) {
  const tower = game.towers.find(t => t.id === command.towerId);
  if (!tower) return reject(game, command, 'noSuchTower');
  const cost = TOWERS[tower.type].cost[tower.level + 1];
  if (cost === undefined) return reject(game, command, 'maxLevel');
  if (game.gold < cost) return reject(game, command, 'notEnoughGold');
  game.gold -= cost;
  tower.invested += cost;
  tower.level++;
  game.events.push({
    type: 'towerUpgraded',
    towerId: tower.id,
    level: tower.level,
  });
}

function sell(game: GameState, command: Extract<Command, {type: 'sell'}>) {
  const tower = game.towers.find(t => t.id === command.towerId);
  if (!tower) return reject(game, command, 'noSuchTower');
  const refund = Math.floor(tower.invested * RULES.sellRefund);
  game.gold += refund;
  game.towers = game.towers.filter(t => t !== tower);
  game.events.push({type: 'towerSold', towerId: tower.id, refund});
}

function launchWave(game: GameState, command: Command) {
  if (game.running && game.spawners.length > 0) {
    return reject(game, command, 'waveInProgress');
  }
  const earlyBonus = game.running
    ? RULES.earlyCallBase + game.wave * RULES.earlyCallPerWave
    : 0;
  game.gold += earlyBonus;
  game.wave++;
  game.running = true;
  startWave(game);
  game.events.push({type: 'waveLaunched', wave: game.wave, earlyBonus});
}

function apply(game: GameState, command: Command) {
  if (game.over) return reject(game, command, 'gameOver');
  switch (command.type) {
    case 'build':
      return build(game, command);
    case 'upgrade':
      return upgrade(game, command);
    case 'sell':
      return sell(game, command);
    case 'launchWave':
      return launchWave(game, command);
  }
}

/**
 * Runs one fixed simulation tick: queued commands first, in order, then the
 * systems. Mutates `game` in place.
 */
export function tick(game: GameState): void {
  game.events = [];
  const commands = game.pending;
  game.pending = [];
  for (const command of commands) apply(game, command);
  if (!game.over) {
    stepSpawners(game);
    stepCombat(game);
    if (!game.over) settleWave(game);
  }
  game.tick++;
}
