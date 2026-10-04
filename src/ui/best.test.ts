import {describe, expect, it} from 'vitest';
import {loadBest, saveBest} from './best';
import type {KeyValueStore} from './best';

function memory(initial: Record<string, string> = {}): KeyValueStore {
  const data = {...initial};
  return {
    getItem: key => data[key] ?? null,
    setItem: (key, value) => void (data[key] = value),
  };
}

const broken: KeyValueStore = {
  getItem: () => {
    throw new Error('blocked');
  },
  setItem: () => {
    throw new Error('blocked');
  },
};

describe('best wave', () => {
  it('starts at 0 and remembers the best', () => {
    const store = memory();
    expect(loadBest(store)).toBe(0);
    expect(saveBest(store, 0, 4)).toBe(4);
    expect(loadBest(store)).toBe(4);
  });

  it('never lowers the best', () => {
    const store = memory();
    saveBest(store, 0, 9);
    expect(saveBest(store, 9, 3)).toBe(9);
    expect(loadBest(store)).toBe(9);
  });

  it('reads the key the 2D prototype used', () => {
    expect(loadBest(memory({'scrapline-best': '12'}))).toBe(12);
  });

  it.each(['abc', '-3', '1.5', ''])('ignores a bad stored value %j', raw => {
    expect(loadBest(memory({'scrapline-best': raw}))).toBe(0);
  });

  it('works without storage (private mode, blocked site data)', () => {
    expect(loadBest(broken)).toBe(0);
    expect(saveBest(broken, 2, 5)).toBe(5);
  });
});
