import {PALETTE} from '../palette';
import type {Part} from './parts';
import {box, cylinder} from './parts';

const LIT_OFF = 0x39424f;

/** Round plinth with three level pips: lit up to the tower's level. */
export function towerBase(tint: number, level: number): Part[] {
  const pips: Part[] = [0, 1, 2].map(i => ({
    geometry: box(0.1, 0.05, 0.05),
    color: i <= level ? tint : LIT_OFF,
    position: [(i - 1) * 0.13, 0.14, 0.3] as const,
  }));
  return [
    {
      geometry: cylinder(0.36, 0.4, 0.12, 12),
      color: 0x2b3440,
      position: [0, 0.06, 0],
    },
    ...pips,
  ];
}

export const TOWER_TINT = PALETTE.towers;
