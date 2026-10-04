import {RULES} from '../../content';
import {TICK_SECONDS} from '../time';

export {TICK_SECONDS};

/** Real time carried between frames, in seconds. Plain data. */
export interface Clock {
  accumulator: number;
}

export function createClock(): Clock {
  return {accumulator: 0};
}

/**
 * Turns real elapsed time into a number of simulation ticks to run this
 * frame. Game speed multiplies the tick count; the tick itself stays fixed.
 * A long frame is clamped so a stalled tab cannot trigger a burst of ticks.
 */
export function advanceClock(
  clock: Clock,
  elapsedSeconds: number,
  speed: number
): number {
  if (!Number.isInteger(speed) || speed < 1 || speed > RULES.maxGameSpeed) {
    throw new RangeError(`game speed must be 1 to ${RULES.maxGameSpeed}`);
  }
  if (!(elapsedSeconds > 0)) return 0;
  clock.accumulator += Math.min(elapsedSeconds, RULES.maxFrameSeconds);
  const ticks = Math.floor(clock.accumulator / TICK_SECONDS);
  clock.accumulator = Math.max(0, clock.accumulator - ticks * TICK_SECONDS);
  return ticks * speed;
}
