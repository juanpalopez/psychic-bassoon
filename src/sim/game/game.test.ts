import {describe, expect, it} from 'vitest';
import {GRID, RULES, TOWERS} from '../../content';
import type {Cell} from '../map';
import {TICK_SECONDS} from './clock';
import {createGame, submit, tick} from './game';
import type {Command, GameState} from './game';

const SEED = 42;

/** First plate cell that is not on the path, in reading order. */
function plate(game: GameState, index = 0): Cell {
  const cells: Cell[] = [];
  game.map.tiles.forEach((line, row) =>
    line.forEach((tile, col) => {
      if (tile === 'plate') cells.push({col, row});
    })
  );
  const cell = cells[index];
  if (!cell) throw new Error('no plate cell');
  return cell;
}

function run(game: GameState, ...commands: Command[]) {
  for (const command of commands) submit(game, command);
  tick(game);
  return game.events;
}

describe('createGame', () => {
  it('starts with the prototype credits and lives on tick 0', () => {
    const game = createGame(SEED);
    expect(game).toMatchObject({
      seed: SEED,
      tick: 0,
      credits: RULES.startCredits,
      lives: RULES.startLives,
      wave: 0,
      running: false,
      over: false,
      towers: [],
    });
  });

  it('builds the same game from the same seed', () => {
    expect(createGame(SEED)).toEqual(createGame(SEED));
  });

  it('keeps all state as plain data that survives JSON', () => {
    const game = createGame(SEED);
    run(game, {type: 'build', tower: 'welder', ...plate(game)});
    expect(JSON.parse(JSON.stringify(game))).toEqual(game);
  });
});

describe('tick', () => {
  it('advances the tick counter by one', () => {
    const game = createGame(SEED);
    tick(game);
    tick(game);
    expect(game.tick).toBe(2);
  });

  it('changes nothing else when there are no commands', () => {
    const game = createGame(SEED);
    const before = JSON.parse(JSON.stringify({...game, tick: 0})) as unknown;
    tick(game);
    expect({...game, tick: 0}).toEqual(before);
  });

  it('applies commands in the order they were submitted', () => {
    const game = createGame(SEED);
    const cell = plate(game);
    run(
      game,
      {type: 'build', tower: 'welder', ...cell},
      {type: 'build', tower: 'rivetMortar', ...cell}
    );
    expect(game.towers).toHaveLength(1);
    expect(game.towers[0]?.type).toBe('welder');
  });

  it('empties the queue after each tick', () => {
    const game = createGame(SEED);
    run(game, {type: 'launchWave'});
    expect(game.pending).toEqual([]);
  });

  it('does not run commands before the tick', () => {
    const game = createGame(SEED);
    submit(game, {type: 'build', tower: 'welder', ...plate(game)});
    expect(game.towers).toEqual([]);
    expect(game.credits).toBe(RULES.startCredits);
  });

  it('keeps events from one tick only', () => {
    const game = createGame(SEED);
    run(game, {type: 'build', tower: 'welder', ...plate(game)});
    expect(game.events).toHaveLength(1);
    tick(game);
    expect(game.events).toEqual([]);
  });

  it('ignores commands and stops once the game is over', () => {
    const game = createGame(SEED);
    game.over = true;
    const events = run(game, {type: 'launchWave'});
    expect(events).toEqual([
      {
        type: 'commandRejected',
        command: {type: 'launchWave'},
        reason: 'gameOver',
      },
    ]);
    expect(game.wave).toBe(0);
  });
});

describe('build', () => {
  it('places a level-1 tower on a plate and charges its cost', () => {
    const game = createGame(SEED);
    const cell = plate(game);
    const events = run(game, {type: 'build', tower: 'welder', ...cell});
    expect(game.credits).toBe(RULES.startCredits - TOWERS.welder.cost[0]);
    expect(game.towers).toEqual([
      {
        id: 0,
        type: 'welder',
        level: 0,
        ...cell,
        invested: TOWERS.welder.cost[0],
        cooldown: -TICK_SECONDS,
      },
    ]);
    expect(events).toEqual([{type: 'towerBuilt', towerId: 0}]);
  });

  it('gives each tower its own id', () => {
    const game = createGame(SEED);
    run(
      game,
      {type: 'build', tower: 'welder', ...plate(game, 0)},
      {type: 'build', tower: 'welder', ...plate(game, 1)}
    );
    expect(game.towers.map(t => t.id)).toEqual([0, 1]);
  });

  it('rejects a build on the path', () => {
    const game = createGame(SEED);
    const onPath = game.map.path[3];
    if (!onPath) throw new Error('no path');
    const command: Command = {type: 'build', tower: 'welder', ...onPath};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'notAPlate'},
    ]);
    expect(game.credits).toBe(RULES.startCredits);
  });

  it('rejects an unknown tower type instead of throwing', () => {
    const game = createGame(SEED);
    const command = {
      type: 'build',
      tower: 'laser',
      ...plate(game),
    } as unknown as Command;
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'unknownTower'},
    ]);
    expect(game.credits).toBe(RULES.startCredits);
  });

  it('rejects a build off the board', () => {
    const game = createGame(SEED);
    for (const cell of [
      {col: -1, row: 0},
      {col: GRID.cols, row: 0},
      {col: 0, row: GRID.rows},
      {col: 0.5, row: 0},
    ]) {
      const command: Command = {type: 'build', tower: 'welder', ...cell};
      expect(run(game, command)).toEqual([
        {type: 'commandRejected', command, reason: 'notAPlate'},
      ]);
    }
  });

  it('rejects a build on an occupied plate', () => {
    const game = createGame(SEED);
    const cell = plate(game);
    run(game, {type: 'build', tower: 'welder', ...cell});
    const command: Command = {type: 'build', tower: 'welder', ...cell};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'occupied'},
    ]);
    expect(game.towers).toHaveLength(1);
  });

  it('rejects a build the player cannot afford, and allows an exact fit', () => {
    const game = createGame(SEED);
    game.credits = TOWERS.mainlineArc.cost[0] - 1;
    const command: Command = {
      type: 'build',
      tower: 'mainlineArc',
      ...plate(game),
    };
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'notEnoughCredits'},
    ]);
    game.credits = TOWERS.mainlineArc.cost[0];
    run(game, command);
    expect(game.credits).toBe(0);
    expect(game.towers).toHaveLength(1);
  });
});

describe('upgrade', () => {
  function withTower(type: 'welder' | 'rivetMortar' = 'welder') {
    const game = createGame(SEED);
    run(game, {type: 'build', tower: type, ...plate(game)});
    game.credits = 1000;
    return game;
  }

  it('raises the level, charges the next level cost and records it', () => {
    const game = withTower();
    const events = run(game, {type: 'upgrade', towerId: 0});
    expect(game.credits).toBe(1000 - TOWERS.welder.cost[1]);
    expect(game.towers[0]?.level).toBe(1);
    expect(game.towers[0]?.invested).toBe(
      TOWERS.welder.cost[0] + TOWERS.welder.cost[1]
    );
    expect(events).toEqual([{type: 'towerUpgraded', towerId: 0, level: 1}]);
  });

  it('stops at level 3', () => {
    const game = withTower();
    run(game, {type: 'upgrade', towerId: 0});
    run(game, {type: 'upgrade', towerId: 0});
    expect(game.towers[0]?.level).toBe(2);
    const command: Command = {type: 'upgrade', towerId: 0};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'maxLevel'},
    ]);
  });

  it('rejects an upgrade the player cannot afford', () => {
    const game = withTower();
    game.credits = TOWERS.welder.cost[1] - 1;
    const command: Command = {type: 'upgrade', towerId: 0};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'notEnoughCredits'},
    ]);
    expect(game.towers[0]?.level).toBe(0);
  });

  it('rejects an unknown tower', () => {
    const game = createGame(SEED);
    const command: Command = {type: 'upgrade', towerId: 99};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'noSuchTower'},
    ]);
  });
});

describe('sell', () => {
  it('refunds 70% of what was invested, rounded down, and frees the plate', () => {
    const game = createGame(SEED);
    const cell = plate(game);
    run(game, {type: 'build', tower: 'welder', ...cell});
    game.credits = 1000;
    run(game, {type: 'upgrade', towerId: 0});
    const invested = TOWERS.welder.cost[0] + TOWERS.welder.cost[1];
    const events = run(game, {type: 'sell', towerId: 0});
    const refund = Math.floor(invested * RULES.sellRefund);
    expect(game.credits).toBe(1000 - TOWERS.welder.cost[1] + refund);
    expect(game.towers).toEqual([]);
    expect(events).toEqual([{type: 'towerSold', towerId: 0, refund}]);
    run(game, {type: 'build', tower: 'rivetMortar', ...cell});
    expect(game.towers).toHaveLength(1);
  });

  it('rejects an unknown tower', () => {
    const game = createGame(SEED);
    const command: Command = {type: 'sell', towerId: 3};
    expect(run(game, command)).toEqual([
      {type: 'commandRejected', command, reason: 'noSuchTower'},
    ]);
  });
});

describe('launchWave', () => {
  it('starts wave 1', () => {
    const game = createGame(SEED);
    const events = run(game, {type: 'launchWave'});
    expect(game.wave).toBe(1);
    expect(game.running).toBe(true);
    expect(events).toEqual([{type: 'waveLaunched', wave: 1, earlyBonus: 0}]);
    expect(game.credits).toBe(RULES.startCredits);
  });
});
