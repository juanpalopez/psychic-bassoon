import type {BufferGeometry} from 'three';
import {PALETTE} from '../palette';
import {box, compose, cylinder} from './parts';

/** Tracked furnace crawler with glowing vents. Faces +z. */
export function buildSmelter(): BufferGeometry {
  const hull = PALETTE.robots.smelter;
  const track = 0x2b3440;
  return compose([
    {geometry: box(0.2, 0.22, 0.72), color: track, position: [0.3, 0.11, 0]},
    {geometry: box(0.2, 0.22, 0.72), color: track, position: [-0.3, 0.11, 0]},
    {geometry: box(0.56, 0.32, 0.62), color: hull, position: [0, 0.36, 0]},
    {geometry: box(0.46, 0.1, 0.5), color: 0x4a3d31, position: [0, 0.57, 0]},
    {
      geometry: box(0.12, 0.08, 0.1),
      color: 0xff8a3d,
      position: [0.14, 0.64, -0.1],
    },
    {
      geometry: box(0.12, 0.08, 0.1),
      color: 0xff8a3d,
      position: [-0.14, 0.64, -0.1],
    },
    {
      geometry: cylinder(0.06, 0.08, 0.3, 6),
      color: 0x2b3440,
      position: [0, 0.78, -0.2],
    },
  ]);
}
