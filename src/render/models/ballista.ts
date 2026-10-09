import type {BufferGeometry} from 'three';
import {compose, cylinder, box} from './parts';
import {TOWER_TINT, towerBase} from './tower-base';

/** Round turret; every level adds a barrel. */
export function buildBallista(level: number): BufferGeometry {
  const tint = TOWER_TINT.ballista;
  const barrels = Array.from({length: level + 1}, (_, i) => ({
    geometry: box(0.06, 0.06, 0.4),
    color: 0xc9d2dc,
    position: [(i - level / 2) * 0.1, 0.26, 0.28] as const,
  }));
  return compose([
    ...towerBase(tint, level),
    {
      geometry: cylinder(0.18, 0.22, 0.16, 12),
      color: tint,
      position: [0, 0.2, 0],
    },
    ...barrels,
  ]);
}
