import {describe, expect, it} from 'vitest';
import {createBot, fingerprint, run} from '../replay';
import {createClock, TICK_SECONDS} from './clock';
import {stepFrame} from './frame';
import {createGame, submit} from './game';

const SEED = 42;

describe('stepFrame', () => {
  it('runs the ticks the clock allows and reports how many', () => {
    const game = createGame(SEED);
    const clock = createClock();
    expect(stepFrame(game, clock, TICK_SECONDS, 1)).toBe(1);
    expect(game.tick).toBe(1);
    expect(stepFrame(game, clock, TICK_SECONDS, 3)).toBe(3);
    expect(game.tick).toBe(4);
  });

  it('stops running ticks once the game is over', () => {
    const game = createGame(SEED);
    game.over = true;
    expect(stepFrame(game, createClock(), TICK_SECONDS, 3)).toBe(0);
    expect(game.tick).toBe(0);
  });

  it('calls the hook before every tick, with the tick about to run', () => {
    const game = createGame(SEED);
    const seen: number[] = [];
    stepFrame(game, createClock(), TICK_SECONDS, 3, {
      beforeTick: g => seen.push(g.tick),
    });
    expect(seen).toEqual([0, 1, 2]);
  });

  it('stops exactly at the tick limit', () => {
    const game = createGame(SEED);
    expect(
      stepFrame(game, createClock(), TICK_SECONDS, 3, {untilTick: 2})
    ).toBe(2);
    expect(game.tick).toBe(2);
  });

  it('plays the same game at every speed and frame rate', () => {
    // Speed only changes how many ticks run per frame, never the tick, so a
    // run driven by frames at 1x, 2x or 3x matches the tick-by-tick replay.
    const TICKS = 30 * 60 * 3;
    const reference = fingerprint(
      run(SEED, TICKS, createBot(createGame(SEED).map)).game
    );
    for (const [speed, frame] of [
      [1, 1 / 60],
      [2, 1 / 60],
      [3, 1 / 30],
      [3, 1 / 20],
    ] as const) {
      const game = createGame(SEED);
      const clock = createClock();
      const bot = createBot(game.map);
      while (game.tick < TICKS && !game.over) {
        stepFrame(game, clock, frame, speed, {
          untilTick: TICKS,
          beforeTick: g => {
            for (const command of bot(g)) submit(g, command);
          },
        });
      }
      expect(game.tick).toBe(TICKS);
      expect(fingerprint(game)).toBe(reference);
    }
  });
});
