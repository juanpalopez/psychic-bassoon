import type {Enemy, GameState} from '../sim';
import type {FoePose} from './units';

interface Track {
  prevX: number;
  prevY: number;
  heading: number;
  /** Poses are written into this object so a frame allocates nothing. */
  pose: {-readonly [K in keyof FoePose]: FoePose[K]};
}

export interface Interpolator {
  /** Call before each sim tick: remembers where every foe is now. */
  capture(game: GameState): void;
  /**
   * Fills `out` with foe poses `alpha` (0..1) of the way from the last
   * captured positions to the current ones.
   */
  poses(game: GameState, alpha: number, out: FoePose[]): void;
}

function newTrack(tracks: Map<number, Track>, enemy: Enemy): Track {
  const track: Track = {
    prevX: enemy.x,
    prevY: enemy.y,
    heading: 0,
    pose: {type: enemy.type, x: enemy.x, y: enemy.y, heading: 0},
  };
  tracks.set(enemy.id, track);
  return track;
}

/**
 * The sim ticks at 30 Hz but the screen draws at 60 Hz or more, so foes are
 * drawn between their last two tick positions. Render-only; reads the game.
 */
export function createInterpolator(): Interpolator {
  const tracks = new Map<number, Track>();
  const live = new Set<number>();
  return {
    capture(game) {
      live.clear();
      for (const enemy of game.enemies) {
        live.add(enemy.id);
        const track = tracks.get(enemy.id) ?? newTrack(tracks, enemy);
        track.prevX = enemy.x;
        track.prevY = enemy.y;
      }
      for (const id of tracks.keys()) if (!live.has(id)) tracks.delete(id);
    },
    poses(game, alpha, out) {
      out.length = game.enemies.length;
      for (let i = 0; i < game.enemies.length; i++) {
        const enemy = game.enemies[i];
        if (!enemy) continue;
        const track = tracks.get(enemy.id) ?? newTrack(tracks, enemy);
        const dx = enemy.x - track.prevX;
        const dy = enemy.y - track.prevY;
        if (dx !== 0 || dy !== 0) track.heading = Math.atan2(dx, dy);
        track.pose.x = track.prevX + dx * alpha;
        track.pose.y = track.prevY + dy * alpha;
        track.pose.heading = track.heading;
        out[i] = track.pose;
      }
    },
  };
}
