import {describe, expect, it} from 'vitest';
import {cloneRng, createRng, nextFloat, nextInt, nextRange, pick} from './rng';

// Reference values from the well-known mulberry32 snippet, run independently.
const GOLDEN: [number, number[]][] = [
  [
    1,
    [
      0.6270739405881613, 0.002735721180215478, 0.5274470399599522,
      0.9810509674716741, 0.9683778982143849,
    ],
  ],
  [
    42,
    [
      0.6011037519201636, 0.44829055899754167, 0.8524657934904099,
      0.6697340414393693, 0.17481389874592423,
    ],
  ],
  [
    4294967295,
    [
      0.8964226141106337, 0.189478256739676, 0.7156526781618595,
      0.9440599093213677, 0.8452364315744489,
    ],
  ],
];

function draw(seed: number, count: number): number[] {
  const rng = createRng(seed);
  return Array.from({length: count}, () => nextFloat(rng));
}

describe('nextFloat', () => {
  it.each(GOLDEN)(
    'matches the reference mulberry32 for seed %i',
    (seed, expected) => {
      expect(draw(seed, expected.length)).toEqual(expected);
    }
  );

  it('replays the same sequence from the same seed', () => {
    expect(draw(2024, 1000)).toEqual(draw(2024, 1000));
  });

  it('gives different sequences for different seeds', () => {
    expect(draw(1, 10)).not.toEqual(draw(2, 10));
  });

  it('stays inside [0, 1)', () => {
    for (const value of draw(99, 10_000)) {
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });
});

describe('createRng', () => {
  it('reduces any integer seed to 32 bits', () => {
    expect(draw(2 ** 32 + 1, 5)).toEqual(draw(1, 5));
    expect(draw(-1, 5)).toEqual(draw(4294967295, 5));
  });

  it('stores the seed as an unsigned 32-bit state', () => {
    expect(createRng(2 ** 32 + 1).state).toBe(1);
    expect(createRng(-1).state).toBe(4294967295);
    expect(createRng(7.9).state).toBe(7);
  });

  it('keeps the state an unsigned 32-bit integer while drawing', () => {
    const rng = createRng(4294967295);
    for (let i = 0; i < 1000; i++) {
      nextFloat(rng);
      expect(Number.isInteger(rng.state)).toBe(true);
      expect(rng.state).toBeGreaterThanOrEqual(0);
      expect(rng.state).toBeLessThan(2 ** 32);
    }
  });

  it('truncates a fractional seed', () => {
    expect(draw(7.9, 5)).toEqual(draw(7, 5));
  });

  it.each([NaN, Infinity, -Infinity])('rejects the seed %s', seed => {
    expect(() => createRng(seed)).toThrow(RangeError);
  });

  it('keeps its state as plain data that survives JSON', () => {
    const original = createRng(5);
    nextFloat(original);
    const restored = JSON.parse(JSON.stringify(original)) as typeof original;
    expect(nextFloat(restored)).toBe(nextFloat(original));
  });
});

describe('cloneRng', () => {
  it('continues the same sequence without sharing state', () => {
    const rng = createRng(11);
    nextFloat(rng);
    const copy = cloneRng(rng);
    const fromCopy = [nextFloat(copy), nextFloat(copy), nextFloat(copy)];
    const fromOriginal = [nextFloat(rng), nextFloat(rng), nextFloat(rng)];
    expect(fromCopy).toEqual(fromOriginal);
  });
});

describe('nextInt', () => {
  it('returns integers in [0, max)', () => {
    const rng = createRng(3);
    for (let i = 0; i < 5000; i++) {
      const value = nextInt(rng, 7);
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(7);
    }
  });

  it('returns 0 when there is a single choice', () => {
    expect(nextInt(createRng(3), 1)).toBe(0);
  });

  it('covers every value roughly evenly (fixed seed)', () => {
    const rng = createRng(7);
    const counts = new Array<number>(6).fill(0);
    for (let i = 0; i < 6000; i++) {
      const value = nextInt(rng, 6);
      counts[value] = (counts[value] ?? 0) + 1;
    }
    for (const count of counts) {
      expect(count).toBeGreaterThan(850);
      expect(count).toBeLessThan(1150);
    }
  });

  it.each([0, -1, 1.5, NaN, Infinity])('rejects the bound %s', max => {
    expect(() => nextInt(createRng(3), max)).toThrow(RangeError);
  });
});

describe('nextRange', () => {
  it('returns floats in [min, max)', () => {
    const rng = createRng(4);
    for (let i = 0; i < 5000; i++) {
      const value = nextRange(rng, 0.8, 3.2);
      expect(value).toBeGreaterThanOrEqual(0.8);
      expect(value).toBeLessThan(3.2);
    }
  });

  it.each([
    [1, 1],
    [2, 1],
    [NaN, 1],
    [0, Infinity],
  ])('rejects the range [%s, %s)', (min, max) => {
    expect(() => nextRange(createRng(4), min, max)).toThrow(RangeError);
  });
});

describe('pick', () => {
  it('returns every item over enough draws and is replayable', () => {
    const items = ['a', 'b', 'c', 'd'] as const;
    const run = () => {
      const rng = createRng(5);
      return Array.from({length: 200}, () => pick(rng, items));
    };
    const first = run();
    expect(run()).toEqual(first);
    expect(new Set(first)).toEqual(new Set(items));
  });

  it('rejects an empty list', () => {
    expect(() => pick(createRng(5), [])).toThrow(RangeError);
  });
});
