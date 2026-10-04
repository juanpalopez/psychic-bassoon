import {advanceClock} from './clock';
import type {Clock} from './clock';
import {tick} from './game';
import type {GameState} from './game';

export interface FrameOptions {
  /** Runs before each tick, to submit that tick's commands. */
  readonly beforeTick?: (game: GameState) => void;
  /** Runs after each tick, to read its events. */
  readonly afterTick?: (game: GameState) => void;
  /** Never run the game past this tick (used by tests and replays). */
  readonly untilTick?: number;
}

/**
 * Advances the game by one rendered frame: `elapsedSeconds` of real time at
 * `speed` becomes a whole number of fixed ticks. Returns how many ran.
 */
export function stepFrame(
  game: GameState,
  clock: Clock,
  elapsedSeconds: number,
  speed: number,
  options: FrameOptions = {}
): number {
  const ticks = advanceClock(clock, elapsedSeconds, speed);
  const limit = options.untilTick ?? Infinity;
  let ran = 0;
  while (ran < ticks && !game.over && game.tick < limit) {
    options.beforeTick?.(game);
    tick(game);
    options.afterTick?.(game);
    ran++;
  }
  return ran;
}
