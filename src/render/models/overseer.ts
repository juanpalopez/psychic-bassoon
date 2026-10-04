import type {BufferGeometry} from 'three';
import {PALETTE} from '../palette';
import {box, cone, compose, sphere} from './parts';

/** Tall boss with a command crown. Faces +z. */
export function buildOverseer(): BufferGeometry {
  const body = PALETTE.robots.overseer;
  const dark = 0x39424f;
  const crown = Array.from({length: 5}, (_, i) => ({
    geometry: cone(0.07, 0.3, 5),
    color: 0xf2b134,
    position: [(i - 2) * 0.16, 1.2, 0] as const,
  }));
  return compose([
    {geometry: box(0.16, 0.42, 0.18), color: dark, position: [0.26, 0.21, 0]},
    {geometry: box(0.16, 0.42, 0.18), color: dark, position: [-0.26, 0.21, 0]},
    {geometry: box(0.82, 0.5, 0.6), color: body, position: [0, 0.67, 0]},
    {geometry: box(0.3, 0.2, 0.2), color: dark, position: [0.52, 0.8, 0]},
    {geometry: box(0.3, 0.2, 0.2), color: dark, position: [-0.52, 0.8, 0]},
    {geometry: box(0.7, 0.12, 0.5), color: 0x8c2f3a, position: [0, 1.0, 0]},
    {geometry: sphere(0.09), color: 0xfff1a8, position: [0, 0.72, 0.32]},
    ...crown,
  ]);
}
