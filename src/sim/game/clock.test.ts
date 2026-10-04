import {describe, expect, it} from 'vitest';
import {RULES} from '../../content';
import {advanceClock, createClock, TICK_SECONDS} from './clock';

describe('clock', () => {
  it('uses a fixed tick of 1/30 s', () => {
    expect(TICK_SECONDS).toBe(1 / RULES.tickRate);
  });

  it('gives no tick until a full tick has elapsed', () => {
    const clock = createClock();
    expect(advanceClock(clock, TICK_SECONDS / 2, 1)).toBe(0);
    expect(advanceClock(clock, TICK_SECONDS / 2, 1)).toBe(1);
  });

  it('carries the remainder to the next frame', () => {
    const clock = createClock();
    let total = 0;
    for (let i = 0; i < 90; i++) total += advanceClock(clock, 0.02, 1);
    // 90 frames of 20 ms is 1.8 s, which is exactly 54 ticks
    expect(total).toBe(54);
  });

  it('runs speed times as many ticks per frame, not bigger ticks', () => {
    for (const speed of [1, 2, 3]) {
      const clock = createClock();
      expect(advanceClock(clock, TICK_SECONDS, speed)).toBe(speed);
    }
  });

  it('clamps a slow frame so a stall cannot cause a burst of ticks', () => {
    const clock = createClock();
    // 0.05 s allows one whole tick of 1/30 s
    expect(advanceClock(clock, 5, 1)).toBe(1);
  });

  it('ignores negative or non-finite elapsed time', () => {
    const clock = createClock();
    expect(advanceClock(clock, -1, 1)).toBe(0);
    expect(advanceClock(clock, NaN, 1)).toBe(0);
  });

  it.each([0, -1, 0.5, 4, NaN])('rejects the game speed %s', speed => {
    expect(() => advanceClock(createClock(), 0.03, speed)).toThrow(RangeError);
  });
});
