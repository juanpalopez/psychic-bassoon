import type {BufferGeometry} from 'three';
import {PALETTE} from '../palette';
import {box, compose, cylinder} from './parts';

const SIDE = Math.PI / 2;

/** Spindly courier drone on three wheels. Faces +z. */
export function buildScamp(): BufferGeometry {
  const body = PALETTE.foes.scamp;
  const dark = 0x39424f;
  return compose([
    {geometry: box(0.28, 0.14, 0.36), color: body, position: [0, 0.18, 0]},
    {
      geometry: box(0.16, 0.06, 0.04),
      color: 0x3ddbd9,
      position: [0, 0.2, 0.19],
    },
    {
      geometry: cylinder(0.09, 0.09, 0.06),
      color: dark,
      position: [0.16, 0.09, 0.1],
      rotation: [0, 0, SIDE],
    },
    {
      geometry: cylinder(0.09, 0.09, 0.06),
      color: dark,
      position: [-0.16, 0.09, 0.1],
      rotation: [0, 0, SIDE],
    },
    {
      geometry: cylinder(0.07, 0.07, 0.06),
      color: dark,
      position: [0, 0.07, -0.14],
      rotation: [0, 0, SIDE],
    },
    {
      geometry: cylinder(0.015, 0.015, 0.22, 5),
      color: dark,
      position: [0, 0.36, -0.1],
    },
  ]);
}
