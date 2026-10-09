import {
  AdditiveBlending,
  BufferAttribute,
  BufferGeometry,
  Color,
  DynamicDrawUsage,
  Group,
  InstancedMesh,
  LineBasicMaterial,
  LineSegments,
  Matrix4,
  MeshBasicMaterial,
  Object3D,
  Points,
  PointsMaterial,
  RingGeometry,
  SphereGeometry,
} from 'three';
import type {GameEvent, Shot} from '../../sim';
import {PALETTE} from '../palette';
import {effectsFromEvent, stepEffects} from './model';
import type {Effect} from './model';

const MAX_SEGMENTS = 256;
const MAX_SPARKS = 512;
const MAX_RINGS = 48;
const MAX_SHELLS = 64;
const EFFECT_HEIGHT = 0.35;
const RING_HEIGHT = 0.08;
const SPARK_COLOR = 0xffd27a;
/** Mid-point wobble of a Storm Spire leg, in cells. */
const ARC_JITTER = 0.14;

export interface EffectsLayer {
  readonly group: Group;
  /** Starts the visuals an event calls for. */
  spawn(event: GameEvent): void;
  /** Drops every running effect (a new game starts). */
  clear(): void;
  /** Draws mortar shells from the sim's shots. */
  setShells(shots: readonly Shot[]): void;
  /** Ages and redraws everything. `dt` is in seconds. */
  update(dt: number): void;
  /** Effects alive right now (for tests and the performance check). */
  readonly active: number;
  dispose(): void;
}

/**
 * Pooled GPU buffers for shot beams, arcs, rings, blasts, sparks and shells:
 * a fixed number of draw calls; buffers are written without temporary arrays
 * (event payloads still allocate a few small objects per shot).
 * `reducedMotion` is read on every spawn so a changed setting applies at once.
 */
export function createEffectsLayer(
  reducedMotion: () => boolean,
  random: () => number = Math.random
): EffectsLayer {
  const group = new Group();
  const effects: Effect[] = [];

  // beams and arcs: one LineSegments with a vertex colour per end
  const linePositions = new Float32Array(MAX_SEGMENTS * 6);
  const lineColors = new Float32Array(MAX_SEGMENTS * 6);
  const lineGeometry = new BufferGeometry();
  lineGeometry.setAttribute(
    'position',
    new BufferAttribute(linePositions, 3).setUsage(DynamicDrawUsage)
  );
  lineGeometry.setAttribute(
    'color',
    new BufferAttribute(lineColors, 3).setUsage(DynamicDrawUsage)
  );
  const lineMaterial = new LineBasicMaterial({
    vertexColors: true,
    blending: AdditiveBlending,
    transparent: true,
    depthWrite: false,
  });
  const lines = new LineSegments(lineGeometry, lineMaterial);
  lines.frustumCulled = false;

  // sparks
  const sparkPositions = new Float32Array(MAX_SPARKS * 3);
  const sparkGeometry = new BufferGeometry();
  sparkGeometry.setAttribute(
    'position',
    new BufferAttribute(sparkPositions, 3).setUsage(DynamicDrawUsage)
  );
  const sparkMaterial = new PointsMaterial({
    color: SPARK_COLOR,
    size: 0.1,
    sizeAttenuation: true,
    transparent: true,
    depthWrite: false,
  });
  const sparks = new Points(sparkGeometry, sparkMaterial);
  sparks.frustumCulled = false;

  // rings and blasts
  const ringGeometry = new RingGeometry(0.92, 1, 28).rotateX(-Math.PI / 2);
  const ringMaterial = new MeshBasicMaterial({
    color: 0xffffff,
    blending: AdditiveBlending,
    transparent: true,
    depthWrite: false,
  });
  const rings = new InstancedMesh(ringGeometry, ringMaterial, MAX_RINGS);
  rings.count = 0;
  rings.frustumCulled = false;
  rings.instanceMatrix.setUsage(DynamicDrawUsage);

  // mortar shells
  const shellGeometry = new SphereGeometry(0.09, 8, 6);
  const shellMaterial = new MeshBasicMaterial({
    color: PALETTE.towers.catapult,
  });
  const shells = new InstancedMesh(shellGeometry, shellMaterial, MAX_SHELLS);
  shells.count = 0;
  shells.frustumCulled = false;

  group.add(lines, sparks, rings, shells);

  const matrix = new Matrix4();
  const dummy = new Object3D();
  const color = new Color();

  const writeSegment = (
    index: number,
    ax: number,
    az: number,
    bx: number,
    bz: number,
    rgb: Color,
    fade: number
  ): void => {
    const o = index * 6;
    const r = rgb.r * fade;
    const g = rgb.g * fade;
    const b = rgb.b * fade;
    // written by index: no temporary arrays in the frame loop
    linePositions[o] = ax;
    linePositions[o + 1] = EFFECT_HEIGHT;
    linePositions[o + 2] = az;
    linePositions[o + 3] = bx;
    linePositions[o + 4] = EFFECT_HEIGHT;
    linePositions[o + 5] = bz;
    lineColors[o] = r;
    lineColors[o + 1] = g;
    lineColors[o + 2] = b;
    lineColors[o + 3] = r;
    lineColors[o + 4] = g;
    lineColors[o + 5] = b;
  };

  return {
    group,
    get active() {
      return effects.length;
    },
    spawn(event) {
      for (const effect of effectsFromEvent(event, reducedMotion(), random)) {
        effects.push(effect);
      }
    },
    clear() {
      effects.length = 0;
    },
    setShells(list) {
      const count = Math.min(list.length, MAX_SHELLS);
      for (let i = 0; i < count; i++) {
        const shot = list[i];
        if (!shot) continue;
        matrix.makeTranslation(shot.x, EFFECT_HEIGHT, shot.y);
        shells.setMatrixAt(i, matrix);
      }
      shells.count = count;
      shells.instanceMatrix.needsUpdate = true;
    },
    update(dt) {
      stepEffects(effects, dt);
      let segments = 0;
      let sparkCount = 0;
      let ringCount = 0;
      for (const effect of effects) {
        const fade = effect.life / effect.max;
        if (effect.kind === 'beam' && segments < MAX_SEGMENTS) {
          color.set(effect.color);
          writeSegment(
            segments++,
            effect.from.x,
            effect.from.y,
            effect.to.x,
            effect.to.y,
            color,
            fade
          );
        } else if (effect.kind === 'arc') {
          color.set(effect.color);
          for (
            let i = 1;
            i < effect.points.length && segments + 1 < MAX_SEGMENTS;
            i++
          ) {
            const a = effect.points[i - 1];
            const b = effect.points[i];
            if (!a || !b) continue;
            const mx = (a.x + b.x) / 2 + (random() - 0.5) * ARC_JITTER * 2;
            const mz = (a.y + b.y) / 2 + (random() - 0.5) * ARC_JITTER * 2;
            writeSegment(segments++, a.x, a.y, mx, mz, color, fade);
            writeSegment(segments++, mx, mz, b.x, b.y, color, fade);
          }
        } else if (effect.kind === 'spark' && sparkCount < MAX_SPARKS) {
          sparkPositions.set(
            [effect.x, EFFECT_HEIGHT, effect.y],
            sparkCount * 3
          );
          sparkCount++;
        } else if (
          (effect.kind === 'ring' || effect.kind === 'boom') &&
          ringCount < MAX_RINGS
        ) {
          // rings widen as they age; blasts start at full size and fade
          const grow = effect.kind === 'ring' ? 1 - fade : 1;
          dummy.position.set(effect.x, RING_HEIGHT, effect.y);
          dummy.scale.setScalar(Math.max(0.05, effect.radius * grow));
          dummy.updateMatrix();
          rings.setMatrixAt(ringCount, dummy.matrix);
          color.set(effect.color).multiplyScalar(fade);
          rings.setColorAt(ringCount, color);
          ringCount++;
        }
      }
      lineGeometry.setDrawRange(0, segments * 2);
      lineGeometry.getAttribute('position').needsUpdate = true;
      lineGeometry.getAttribute('color').needsUpdate = true;
      sparkGeometry.setDrawRange(0, sparkCount);
      sparkGeometry.getAttribute('position').needsUpdate = true;
      rings.count = ringCount;
      rings.instanceMatrix.needsUpdate = true;
      if (rings.instanceColor) rings.instanceColor.needsUpdate = true;
    },
    dispose() {
      for (const item of [
        lineGeometry,
        lineMaterial,
        sparkGeometry,
        sparkMaterial,
        ringGeometry,
        ringMaterial,
        shellGeometry,
        shellMaterial,
      ]) {
        item.dispose();
      }
    },
  };
}
