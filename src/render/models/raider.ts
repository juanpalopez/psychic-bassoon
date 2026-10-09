import type {BufferGeometry} from 'three';
import {PALETTE} from '../palette';
import {box, compose} from './parts';

/** Bipedal loader with a cargo frame on its back. Faces +z. */
export function buildRaider(): BufferGeometry {
  const body = PALETTE.foes.raider;
  const dark = 0x39424f;
  return compose([
    {geometry: box(0.1, 0.26, 0.12), color: dark, position: [0.12, 0.13, 0]},
    {geometry: box(0.1, 0.26, 0.12), color: dark, position: [-0.12, 0.13, 0]},
    {geometry: box(0.4, 0.3, 0.26), color: body, position: [0, 0.41, 0]},
    {
      geometry: box(0.5, 0.08, 0.38),
      color: 0xa8b4c2,
      position: [0, 0.6, -0.02],
    },
    {
      geometry: box(0.32, 0.2, 0.3),
      color: 0xc9a24a,
      position: [0, 0.74, -0.04],
    },
    {
      geometry: box(0.18, 0.06, 0.04),
      color: 0xf2b134,
      position: [0, 0.46, 0.14],
    },
  ]);
}
