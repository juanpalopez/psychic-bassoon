import type {BufferGeometry} from 'three';
import {box, compose, cylinder} from './parts';
import {TOWER_TINT, towerBase} from './tower-base';

/** Squat launcher; every level adds a pair of tubes. */
export function buildCatapult(level: number): BufferGeometry {
  const tint = TOWER_TINT.catapult;
  const tubes = Array.from({length: level + 1}, (_, row) =>
    [-1, 1].map(side => ({
      geometry: cylinder(0.075, 0.09, 0.34, 8),
      color: 0x4a5667,
      position: [side * 0.1, 0.42, 0.04 - row * 0.12] as const,
      rotation: [-0.5, 0, 0] as const,
    }))
  ).flat();
  return compose([
    ...towerBase(tint, level),
    {geometry: box(0.46, 0.2, 0.34), color: tint, position: [0, 0.22, 0]},
    ...tubes,
  ]);
}
