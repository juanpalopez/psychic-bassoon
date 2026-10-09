import {describe, expect, it} from 'vitest';
import {createGame, submit, tick} from '../sim';
import type {GameState} from '../sim';
import {
  buildCommand,
  highlightFor,
  reconcileSelection,
  sellCommand,
  selectAt,
  upgradeCommand,
} from './selection';
import type {Selection} from './selection';

const NONE: Selection = {kind: 'none'};

function withTower(): {game: GameState; col: number; row: number} {
  const game = createGame(42);
  let spot = {col: 0, row: 0};
  game.map.tiles.forEach((line, row) =>
    line.forEach((tile, col) => {
      if (tile === 'plot' && spot.col === 0 && spot.row === 0)
        spot = {col, row};
    })
  );
  submit(game, {type: 'build', tower: 'ballista', ...spot});
  tick(game);
  return {game, ...spot};
}

describe('selectAt', () => {
  it('selects a free plot', () => {
    const game = createGame(42);
    const spot = game.map.tiles.flatMap((l, row) =>
      l.flatMap((t, col) => (t === 'plot' ? [{col, row}] : []))
    )[0];
    expect(selectAt(game, spot)).toEqual({kind: 'plot', ...spot});
  });

  it('selects the tower standing on a plot', () => {
    const {game, col, row} = withTower();
    expect(selectAt(game, {col, row})).toEqual({kind: 'tower', id: 0});
  });

  it('selects nothing on the road, off the board, or with no tap', () => {
    const game = createGame(42);
    const road = game.map.path[2];
    expect(selectAt(game, road)).toEqual(NONE);
    expect(selectAt(game, undefined)).toEqual(NONE);
  });
});

describe('reconcileSelection', () => {
  it('keeps a selected tower that still stands', () => {
    const {game} = withTower();
    const sel: Selection = {kind: 'tower', id: 0};
    expect(reconcileSelection(game, sel)).toBe(sel);
  });

  it('drops a selected tower that was sold', () => {
    const {game} = withTower();
    submit(game, {type: 'sell', towerId: 0});
    tick(game);
    expect(reconcileSelection(game, {kind: 'tower', id: 0})).toEqual(NONE);
  });

  it('turns a selected plot into the tower built on it', () => {
    const {game, col, row} = withTower();
    expect(reconcileSelection(game, {kind: 'plot', col, row})).toEqual({
      kind: 'tower',
      id: 0,
    });
  });
});

describe('commands from a selection', () => {
  it('builds on the selected plot only', () => {
    expect(buildCommand({kind: 'plot', col: 3, row: 4}, 'ballista')).toEqual({
      type: 'build',
      tower: 'ballista',
      col: 3,
      row: 4,
    });
    expect(buildCommand(NONE, 'ballista')).toBeUndefined();
    expect(buildCommand({kind: 'tower', id: 1}, 'ballista')).toBeUndefined();
  });

  it('upgrades and sells the selected tower only', () => {
    expect(upgradeCommand({kind: 'tower', id: 7})).toEqual({
      type: 'upgrade',
      towerId: 7,
    });
    expect(sellCommand({kind: 'tower', id: 7})).toEqual({
      type: 'sell',
      towerId: 7,
    });
    expect(upgradeCommand(NONE)).toBeUndefined();
    expect(sellCommand({kind: 'plot', col: 1, row: 1})).toBeUndefined();
  });
});

describe('highlightFor', () => {
  it('highlights a selected plot with no range', () => {
    const game = createGame(42);
    expect(highlightFor(game, {kind: 'plot', col: 2, row: 3})).toEqual({
      col: 2,
      row: 3,
    });
  });

  it('highlights a selected tower with its current range', () => {
    const {game, col, row} = withTower();
    expect(highlightFor(game, {kind: 'tower', id: 0})).toEqual({
      col,
      row,
      range: 2.3,
    });
    game.gold = 1000;
    submit(game, {type: 'upgrade', towerId: 0});
    tick(game);
    expect(highlightFor(game, {kind: 'tower', id: 0})?.range).toBe(2.6);
  });

  it('highlights nothing with no selection or a gone tower', () => {
    const game = createGame(42);
    expect(highlightFor(game, NONE)).toBeUndefined();
    expect(highlightFor(game, {kind: 'tower', id: 9})).toBeUndefined();
  });
});
