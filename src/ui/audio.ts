import type {GameEvent} from '../sim';

export type Sound = 'shot' | 'kill' | 'leak' | 'wave' | 'build' | 'reject';

/** The few parts of `AudioContext` the game uses, so tests can fake it. */
export interface AudioContextLike {
  readonly currentTime: number;
  readonly destination: unknown;
  resume(): Promise<void>;
  createGain(): {
    gain: {
      value: number;
      setValueAtTime(value: number, time: number): unknown;
      exponentialRampToValueAtTime(value: number, time: number): unknown;
    };
    connect(destination: unknown): unknown;
  };
  createOscillator(): {
    type: string;
    frequency: {value: number};
    connect(destination: unknown): unknown;
    start(time: number): void;
    stop(time: number): void;
  };
}

export interface AudioPort {
  readonly unlocked: boolean;
  /** Call from the first tap. Browsers refuse audio before a gesture. */
  unlock(): void;
  play(sound: Sound): void;
}

/** Pitch (Hz), length (s) and loudness of each blip. */
const BLIPS: Readonly<
  Record<Sound, {hz: number; seconds: number; volume: number}>
> = {
  shot: {hz: 520, seconds: 0.05, volume: 0.04},
  kill: {hz: 300, seconds: 0.09, volume: 0.07},
  leak: {hz: 110, seconds: 0.3, volume: 0.12},
  wave: {hz: 220, seconds: 0.2, volume: 0.08},
  build: {hz: 400, seconds: 0.1, volume: 0.07},
  reject: {hz: 150, seconds: 0.12, volume: 0.06},
};
/** The same sound may not repeat faster than this, in milliseconds. */
const MIN_GAP_MS = 60;

export function soundFor(event: GameEvent): Sound | undefined {
  switch (event.type) {
    case 'enemyKilled':
      return 'kill';
    case 'enemyLeaked':
    case 'gameOver':
      return 'leak';
    case 'towerBuilt':
    case 'towerUpgraded':
      return 'build';
    case 'waveLaunched':
      return 'wave';
    case 'commandRejected':
      return 'reject';
    case 'towerFired':
      return 'shot';
    default:
      return undefined;
  }
}

/**
 * Tiny synthesized blips, no audio files. Nothing is created and nothing
 * plays until `unlock()` runs from a user gesture.
 */
export function createAudio(
  makeContext: () => AudioContextLike,
  nowMs: () => number
): AudioPort {
  let context: AudioContextLike | undefined;
  let failed = false;
  const lastPlayed = new Map<Sound, number>();
  return {
    get unlocked() {
      return context !== undefined;
    },
    unlock() {
      if (context || failed) return;
      try {
        context = makeContext();
        void context.resume().catch(() => undefined);
      } catch {
        failed = true;
      }
    },
    play(sound) {
      if (!context) return;
      const now = nowMs();
      const last = lastPlayed.get(sound);
      if (last !== undefined && now - last < MIN_GAP_MS) return;
      lastPlayed.set(sound, now);
      const blip = BLIPS[sound];
      const t = context.currentTime;
      const osc = context.createOscillator();
      const gain = context.createGain();
      osc.type = 'square';
      osc.frequency.value = blip.hz;
      gain.gain.setValueAtTime(blip.volume, t);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + blip.seconds);
      osc.connect(gain);
      gain.connect(context.destination);
      osc.start(t);
      osc.stop(t + blip.seconds);
    },
  };
}
