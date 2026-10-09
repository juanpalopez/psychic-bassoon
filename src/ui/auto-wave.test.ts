import {describe, expect, it} from 'vitest';
import {createGame, submit, tick} from '../sim';
import type {GameState} from '../sim';
import {loadAutoStart, saveAutoStart, shouldAutoLaunch} from './auto-wave';
import type {KeyValueStore} from './best';

function cleared(): GameState {
  const game = createGame(1);
  game.wave = 3;
  game.running = false;
  return game;
}

describe('shouldAutoLaunch', () => {
  it('launches the next wave once a wave is cleared and auto is on', () => {
    expect(shouldAutoLaunch(cleared(), true, false)).toBe(true);
  });

  it('never launches with auto off', () => {
    expect(shouldAutoLaunch(cleared(), false, false)).toBe(false);
  });

  it('does not start the very first wave by itself', () => {
    const game = createGame(1);
    expect(shouldAutoLaunch(game, true, false)).toBe(false);
  });

  it('waits while a wave is running, the game is paused or over', () => {
    const running = cleared();
    running.running = true;
    expect(shouldAutoLaunch(running, true, false)).toBe(false);
    expect(shouldAutoLaunch(cleared(), true, true)).toBe(false);
    const over = cleared();
    over.over = true;
    expect(shouldAutoLaunch(over, true, false)).toBe(false);
  });

  it('does not queue a second launch while one is pending', () => {
    const game = cleared();
    submit(game, {type: 'launchWave'});
    expect(shouldAutoLaunch(game, true, false)).toBe(false);
    tick(game);
    expect(game.running).toBe(true);
    expect(shouldAutoLaunch(game, true, false)).toBe(false);
  });
});

describe('auto-start setting', () => {
  const memory = (): KeyValueStore & {data: Record<string, string>} => {
    const data: Record<string, string> = {};
    return {
      data,
      getItem: k => data[k] ?? null,
      setItem: (k, v) => void (data[k] = v),
    };
  };

  it('is off by default and remembers a choice', () => {
    const store = memory();
    expect(loadAutoStart(store)).toBe(false);
    saveAutoStart(store, true);
    expect(loadAutoStart(store)).toBe(true);
    saveAutoStart(store, false);
    expect(loadAutoStart(store)).toBe(false);
  });

  it('works when storage is blocked', () => {
    const broken: KeyValueStore = {
      getItem: () => {
        throw new Error('blocked');
      },
      setItem: () => {
        throw new Error('blocked');
      },
    };
    expect(loadAutoStart(broken)).toBe(false);
    expect(() => saveAutoStart(broken, true)).not.toThrow();
  });
});
