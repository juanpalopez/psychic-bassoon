import {GRID, RULES, TOWERS} from '../../content';
import type {TowerId} from '../../content';
import {generateMap} from '../map';
import type {GameMap} from '../map';

/** A tower on a plate. `level` counts from 0 (level 1) to 2 (level 3). */
export interface Tower {
  readonly id: number;
  readonly type: TowerId;
  level: number;
  readonly col: number;
  readonly row: number;
  /** Credits spent so far; a sale refunds a share of it. */
  invested: number;
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
  | 'notAPlate'
  | 'occupied'
  | 'notEnoughCredits'
  | 'maxLevel'
  | 'noSuchTower';

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
  tick: number;
  credits: number;
  lives: number;
  /** Number of the wave most recently launched; 0 before the first. */
  wave: number;
  running: boolean;
  over: boolean;
  towers: Tower[];
  nextId: number;
  /** Commands waiting for the next tick, in submission order. */
  pending: Command[];
  /** Events from the last tick only. */
  events: GameEvent[];
}

export function createGame(seed: number): GameState {
  return {
    seed,
    map: generateMap(seed),
    tick: 0,
    credits: RULES.startCredits,
    lives: RULES.startLives,
    wave: 0,
    running: false,
    over: false,
    towers: [],
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

function isPlate(game: GameState, col: number, row: number): boolean {
  return (
    Number.isInteger(col) &&
    Number.isInteger(row) &&
    col >= 0 &&
    col < GRID.cols &&
    row >= 0 &&
    row < GRID.rows &&
    game.map.tiles[row]?.[col] === 'plate'
  );
}

function build(game: GameState, command: Extract<Command, {type: 'build'}>) {
  const {tower, col, row} = command;
  if (!isPlate(game, col, row)) return reject(game, command, 'notAPlate');
  if (game.towers.some(t => t.col === col && t.row === row)) {
    return reject(game, command, 'occupied');
  }
  const cost = TOWERS[tower].cost[0];
  if (game.credits < cost) return reject(game, command, 'notEnoughCredits');
  game.credits -= cost;
  const id = game.nextId++;
  game.towers.push({id, type: tower, level: 0, col, row, invested: cost});
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
  if (game.credits < cost) return reject(game, command, 'notEnoughCredits');
  game.credits -= cost;
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
  game.credits += refund;
  game.towers = game.towers.filter(t => t !== tower);
  game.events.push({type: 'towerSold', towerId: tower.id, refund});
}

function launchWave(game: GameState) {
  const earlyBonus = game.running
    ? RULES.earlyCallBase + game.wave * RULES.earlyCallPerWave
    : 0;
  game.credits += earlyBonus;
  game.wave++;
  game.running = true;
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
      return launchWave(game);
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
  game.tick++;
}
