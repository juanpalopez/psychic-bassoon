import {createGame, submit, tick} from '../game';
import type {Command, GameEvent, GameState} from '../game';

/** A command and the tick it was submitted on (before that tick ran). */
export interface ScheduledCommand {
  readonly tick: number;
  readonly command: Command;
}

/** An event and the tick that produced it. */
export interface LoggedEvent {
  readonly tick: number;
  readonly event: GameEvent;
}

export interface RunResult {
  readonly game: GameState;
  /** Every command that was submitted, in order. */
  readonly log: readonly ScheduledCommand[];
  /** Every event, in order. */
  readonly events: readonly LoggedEvent[];
}

/**
 * A short, stable hash of the whole game state (FNV-1a over its JSON). Two
 * runs ended in the same state exactly when their fingerprints match.
 */
export function fingerprint(game: GameState): string {
  const text = JSON.stringify(game);
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

/**
 * Runs a game from its seed. `commandsFor` supplies the commands to submit
 * before each tick; the run stops at `ticks` or at game over.
 */
export function run(
  seed: number,
  ticks: number,
  commandsFor: (game: GameState) => readonly Command[]
): RunResult {
  const game = createGame(seed);
  const log: ScheduledCommand[] = [];
  const events: LoggedEvent[] = [];
  while (game.tick < ticks && !game.over) {
    for (const command of commandsFor(game)) {
      log.push({tick: game.tick, command});
      submit(game, command);
    }
    tick(game);
    for (const event of game.events) events.push({tick: game.tick, event});
  }
  return {game, log, events};
}

/** Replays a recorded command list against a fresh game from the same seed. */
export function runReplay(
  seed: number,
  log: readonly ScheduledCommand[],
  ticks: number
): RunResult {
  return run(seed, ticks, game =>
    log.filter(c => c.tick === game.tick).map(c => c.command)
  );
}
