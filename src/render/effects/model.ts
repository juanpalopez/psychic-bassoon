import {TOWERS} from '../../content';
import type {EnemyId} from '../../content';
import type {GameEvent} from '../../sim';
import {PALETTE} from '../palette';

interface Point {
  readonly x: number;
  readonly y: number;
}

/** A short-lived visual. Plain data; the GPU layer draws it. */
export type Effect =
  | {
      kind: 'beam';
      from: Point;
      to: Point;
      color: number;
      life: number;
      max: number;
    }
  | {kind: 'arc'; points: Point[]; color: number; life: number; max: number}
  | {
      kind: 'ring';
      x: number;
      y: number;
      radius: number;
      color: number;
      life: number;
      max: number;
    }
  | {
      kind: 'boom';
      x: number;
      y: number;
      radius: number;
      color: number;
      life: number;
      max: number;
    }
  | {
      kind: 'spark';
      x: number;
      y: number;
      vx: number;
      vy: number;
      life: number;
      max: number;
    };

/** Lifetimes in seconds, from the 2D prototype. */
const LIFE = {beam: 0.09, arc: 0.14, ring: 0.45, boom: 0.35, spark: 0.5};
const SPARKS = {robot: 10, overseer: 26};
/** Reduced motion keeps a few sparks so a kill still reads. */
const REDUCED_SPARK_SHARE = 0.25;
const SPARK_DRAG = 0.9;
const BOOM_COLOR = PALETTE.towers.rivetMortar;

export function sparkCount(robot: EnemyId, reducedMotion: boolean): number {
  const full = robot === 'overseer' ? SPARKS.overseer : SPARKS.robot;
  return reducedMotion
    ? Math.max(1, Math.floor(full * REDUCED_SPARK_SHARE))
    : full;
}

/**
 * The visuals an event calls for. `random` supplies spark directions; it is
 * render-only, so it may be `Math.random` (the sim never sees it).
 */
export function effectsFromEvent(
  event: GameEvent,
  reducedMotion: boolean,
  random: () => number
): Effect[] {
  switch (event.type) {
    case 'towerFired': {
      const color = PALETTE.towers[event.tower];
      const from = {x: event.x, y: event.y};
      if (event.tower === 'welder' && event.path[0]) {
        return [
          {
            kind: 'beam',
            from,
            to: event.path[0],
            color,
            life: LIFE.beam,
            max: LIFE.beam,
          },
        ];
      }
      if (event.tower === 'mainlineArc') {
        return [
          {
            kind: 'arc',
            points: [from, ...event.path],
            color,
            life: LIFE.arc,
            max: LIFE.arc,
          },
        ];
      }
      if (event.tower === 'quenchCoil') {
        return [
          {
            kind: 'ring',
            x: from.x,
            y: from.y,
            radius: TOWERS.quenchCoil.range[event.level] ?? 1,
            color,
            life: LIFE.ring,
            max: LIFE.ring,
          },
        ];
      }
      return [];
    }
    case 'shellLanded':
      return [
        {
          kind: 'boom',
          x: event.x,
          y: event.y,
          radius: event.splash,
          color: BOOM_COLOR,
          life: LIFE.boom,
          max: LIFE.boom,
        },
      ];
    case 'enemyKilled': {
      const sparks: Effect[] = [];
      const count = sparkCount(event.robot, reducedMotion);
      for (let i = 0; i < count; i++) {
        const angle = random() * Math.PI * 2;
        const speed = 0.8 + random() * 2.4;
        sparks.push({
          kind: 'spark',
          x: event.x,
          y: event.y,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          life: LIFE.spark,
          max: LIFE.spark,
        });
      }
      return sparks;
    }
    default:
      return [];
  }
}

/** Ages every effect by `dt` seconds and drops the finished ones, in place. */
export function stepEffects(effects: Effect[], dt: number): void {
  let kept = 0;
  for (const effect of effects) {
    effect.life -= dt;
    if (effect.life <= 0) continue;
    if (effect.kind === 'spark') {
      effect.x += effect.vx * dt;
      effect.y += effect.vy * dt;
      effect.vx *= SPARK_DRAG;
      effect.vy *= SPARK_DRAG;
    }
    effects[kept++] = effect;
  }
  effects.length = kept;
}
