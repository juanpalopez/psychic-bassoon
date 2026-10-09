import type {BufferGeometry} from 'three';
import {cone, compose, cylinder, sphere} from './parts';
import {TOWER_TINT, towerBase} from './tower-base';

/** Pylon crowned with prongs; every level adds two prongs. */
export function buildStormSpire(level: number): BufferGeometry {
  const tint = TOWER_TINT.stormSpire;
  const count = 4 + level * 2;
  const prongs = Array.from({length: count}, (_, i) => {
    const angle = (i / count) * Math.PI * 2;
    return {
      geometry: cone(0.04, 0.22, 5),
      color: tint,
      position: [Math.sin(angle) * 0.14, 0.62, Math.cos(angle) * 0.14] as const,
      rotation: [Math.cos(angle) * 0.4, 0, -Math.sin(angle) * 0.4] as const,
    };
  });
  return compose([
    ...towerBase(tint, level),
    {
      geometry: cylinder(0.07, 0.14, 0.5, 8),
      color: 0x4a5667,
      position: [0, 0.37, 0],
    },
    ...prongs,
    {geometry: sphere(0.07), color: 0xfbffc2, position: [0, 0.66, 0]},
  ]);
}
