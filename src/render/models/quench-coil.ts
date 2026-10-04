import type {BufferGeometry} from 'three';
import {compose, cylinder, ring, sphere} from './parts';
import {TOWER_TINT, towerBase} from './tower-base';

/** Pole wound with rings; every level adds a ring. */
export function buildQuenchCoil(level: number): BufferGeometry {
  const tint = TOWER_TINT.quenchCoil;
  const rings = Array.from({length: level + 2}, (_, i) => ({
    geometry: ring(0.24 - i * 0.03, 0.04),
    color: tint,
    position: [0, 0.2 + i * 0.12, 0] as const,
    rotation: [Math.PI / 2, 0, 0] as const,
  }));
  return compose([
    ...towerBase(tint, level),
    {
      geometry: cylinder(0.05, 0.06, 0.46, 8),
      color: 0x4a5667,
      position: [0, 0.35, 0],
    },
    ...rings,
    {
      geometry: sphere(0.08),
      color: 0xd8d2ff,
      position: [0, 0.62 + level * 0.08, 0],
    },
  ]);
}
