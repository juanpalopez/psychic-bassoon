import type {GameState} from '../sim';
import type {KeyValueStore} from './best';

const AUTO_KEY = 'scrapline-auto-start';

/**
 * True when auto-start should send `launchWave` now: a wave has been played
 * and cleared, nothing is pending, and the game is running. The first wave is
 * always the player's call.
 */
export function shouldAutoLaunch(
  game: GameState,
  autoStart: boolean,
  paused: boolean
): boolean {
  return (
    autoStart &&
    !paused &&
    !game.over &&
    !game.running &&
    game.wave >= 1 &&
    !game.pending.some(c => c.type === 'launchWave')
  );
}

export function loadAutoStart(store: KeyValueStore): boolean {
  try {
    return store.getItem(AUTO_KEY) === '1';
  } catch {
    return false;
  }
}

export function saveAutoStart(store: KeyValueStore, on: boolean): void {
  try {
    store.setItem(AUTO_KEY, on ? '1' : '0');
  } catch {
    // storage blocked: the choice lasts for this session only
  }
}
