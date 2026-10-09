import {describe, expect, it} from 'vitest';
import {RULES, TOWERS} from '../content';
import {createGame, submit, tick} from '../sim';
import type {GameState} from '../sim';
import {hudModel, toastFor} from './hud-model';
import type {Selection} from './selection';

const NONE: Selection = {kind: 'none'};

function plot(game: GameState) {
  for (let row = 0; row < game.map.tiles.length; row++) {
    const col = game.map.tiles[row]?.indexOf('plot') ?? -1;
    if (col >= 0) return {col, row};
  }
  throw new Error('no plot');
}

describe('hudModel top bar', () => {
  it('shows gold, lives and wave, and warns at 5 lives or fewer', () => {
    const game = createGame(1);
    const m = hudModel(game, NONE, 7);
    expect([m.gold, m.lives, m.wave, m.best]).toEqual([180, 20, 0, 7]);
    expect(m.lowLives).toBe(false);
    game.lives = 5;
    expect(hudModel(game, NONE, 0).lowLives).toBe(true);
  });
});

describe('hudModel launch button', () => {
  it('offers the next wave, then an early call, then waits while spawning', () => {
    const game = createGame(1);
    expect(hudModel(game, NONE, 0).launch).toEqual({
      label: 'Launch wave 1',
      enabled: true,
    });
    submit(game, {type: 'launchWave'});
    tick(game);
    expect(hudModel(game, NONE, 0).launch).toEqual({
      label: 'Wave 1 incoming',
      enabled: false,
    });
    game.spawners = [];
    const bonus = RULES.earlyCallBase + RULES.earlyCallPerWave;
    expect(hudModel(game, NONE, 0).launch).toEqual({
      label: `Call wave 2 · +${bonus}`,
      enabled: true,
    });
  });

  it('is disabled once the game is over', () => {
    const game = createGame(1);
    game.over = true;
    expect(hudModel(game, NONE, 0).launch.enabled).toBe(false);
  });
});

describe('hudModel panel', () => {
  it('shows a hint with no selection', () => {
    expect(hudModel(createGame(1), NONE, 0).panel.kind).toBe('hint');
  });

  it('lists all four towers with cost and whether they are affordable', () => {
    const game = createGame(1);
    game.gold = 60;
    const sel: Selection = {kind: 'plot', ...plot(game)};
    const panel = hudModel(game, sel, 0).panel;
    if (panel.kind !== 'build') throw new Error('expected build panel');
    expect(panel.options.map(o => [o.id, o.cost, o.affordable])).toEqual([
      ['ballista', 50, true],
      ['catapult', 90, false],
      ['frostSpire', 70, false],
      ['stormSpire', 110, false],
    ]);
  });

  it('shows a tower with its stats, the next level and the sale value', () => {
    const game = createGame(1);
    submit(game, {type: 'build', tower: 'ballista', ...plot(game)});
    tick(game);
    game.gold = 1000;
    const panel = hudModel(game, {kind: 'tower', id: 0}, 0).panel;
    if (panel.kind !== 'tower') throw new Error('expected tower panel');
    expect(panel.name).toBe('Ballista');
    expect(panel.level).toBe(1);
    expect(panel.stats).toEqual([
      {label: 'Dmg', value: '9', next: '15'},
      {label: 'Range', value: '2.3', next: '2.6'},
      {label: 'Rate/s', value: '3.0', next: '3.6'},
      {label: 'DPS', value: '27', next: '54'},
    ]);
    expect(panel.upgrade).toEqual({cost: 60, affordable: true});
    expect(panel.sell).toBe(Math.floor(50 * RULES.sellRefund));
  });

  it('shows the special stat of each tower and no upgrade at max level', () => {
    const game = createGame(1);
    submit(game, {type: 'build', tower: 'frostSpire', ...plot(game)});
    tick(game);
    game.gold = 1000;
    for (let i = 0; i < 2; i++) {
      submit(game, {type: 'upgrade', towerId: 0});
      tick(game);
    }
    const panel = hudModel(game, {kind: 'tower', id: 0}, 0).panel;
    if (panel.kind !== 'tower') throw new Error('expected tower panel');
    expect(panel.level).toBe(3);
    expect(panel.upgrade).toBeUndefined();
    expect(panel.stats[3]).toEqual({label: 'Slow', value: '55%'});
    expect(panel.sell).toBe(
      Math.floor(
        (TOWERS.frostSpire.cost[0] +
          TOWERS.frostSpire.cost[1] +
          TOWERS.frostSpire.cost[2]) *
          RULES.sellRefund
      )
    );
  });

  it('disables the upgrade when the player cannot pay', () => {
    const game = createGame(1);
    submit(game, {type: 'build', tower: 'ballista', ...plot(game)});
    tick(game);
    game.gold = 59;
    const panel = hudModel(game, {kind: 'tower', id: 0}, 0).panel;
    if (panel.kind !== 'tower') throw new Error('expected tower panel');
    expect(panel.upgrade).toEqual({cost: 60, affordable: false});
  });
});

describe('toastFor', () => {
  it('words the events a player should notice', () => {
    expect(toastFor({type: 'waveCleared', wave: 3, bonus: 21})).toBe(
      'Wave 3 cleared +21'
    );
    expect(toastFor({type: 'waveLaunched', wave: 4, earlyBonus: 12})).toBe(
      'Early call +12'
    );
    expect(toastFor({type: 'waveLaunched', wave: 10, earlyBonus: 0})).toBe(
      'Wave 10: Warlord incoming'
    );
    expect(toastFor({type: 'waveLaunched', wave: 5, earlyBonus: 0})).toBe(
      'Wave 5: Scamp swarm'
    );
    expect(
      toastFor({type: 'waveLaunched', wave: 6, earlyBonus: 0})
    ).toBeUndefined();
    expect(
      toastFor({
        type: 'commandRejected',
        command: {type: 'launchWave'},
        reason: 'notEnoughGold',
      })
    ).toBe('Not enough gold');
    expect(toastFor({type: 'towerBuilt', towerId: 1})).toBeUndefined();
  });
});
