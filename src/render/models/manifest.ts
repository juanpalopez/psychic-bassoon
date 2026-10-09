import type {EnemyId, TowerId} from '../../content';
import {PALETTE} from '../palette';

/** One GLB file placed inside a unit. All parts of a unit share one kit. */
export interface GlbPart {
  /** Path under `public/assets/models/`. */
  readonly file: string;
  readonly position?: readonly [number, number, number];
  /** Radians about the vertical axis, to make the model face +z. */
  readonly rotationY?: number;
  readonly scale?: number;
}

export interface GlbUnit {
  readonly parts: readonly GlbPart[];
  /** Multiplies the kit's colours, so one palette can serve many units. */
  readonly tint?: number;
}

/**
 * Units that use a CC0 model. Any unit not listed (or whose files fail to
 * load) keeps its primitive builder, so a missing asset never breaks the
 * game. Every file named here must be recorded in `assets/CREDITS.md`.
 */
export const FOE_GLB: Readonly<Partial<Record<EnemyId, GlbUnit>>> = {
  // Kenney Mini Dungeon characters: about 0.8 tall and facing +z already.
  scamp: {parts: [{file: 'mini-dungeon/character-orc.glb', scale: 0.55}]},
  raider: {parts: [{file: 'mini-dungeon/character-human.glb', scale: 1.1}]},
  // Kenney siege tower, the tallest foe: it is 2.9 tall at scale 1.
  warlord: {
    parts: [
      {
        file: 'castle-kit/siege-tower.glb',
        rotationY: -Math.PI / 2,
        scale: 0.42,
      },
    ],
  },
  // Kenney siege ram; its long axis is x, so turn it to face +z.
  ironclad: {
    parts: [
      {file: 'castle-kit/siege-ram.glb', rotationY: -Math.PI / 2, scale: 0.4},
    ],
  },
};

/** Mixes a colour halfway to white, so the kit's texture still shows. */
function pastel(hex: number): number {
  const channel = (shift: number) =>
    Math.round((((hex >> shift) & 255) + 255) / 2);
  return (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/**
 * Our own towers, built in Blender by `assets-src/blender/towers.py`: one
 * file per tower and level, already facing +z with the base at the origin.
 * Each level is a taller model, so the level reads from the height alone.
 */
const ownTower =
  (name: string) =>
  (level: number): GlbUnit => ({
    parts: [{file: `scrapline/${name}-${level}.glb`}],
  });

export const TOWER_GLB: Readonly<
  Partial<Record<TowerId, (level: number) => GlbUnit>>
> = {
  ballista: ownTower('ballista'),
  catapult: ownTower('catapult'),
  frostSpire: ownTower('frost-spire'),
  stormSpire: ownTower('storm-spire'),
};

/** Scenery pieces outside the unit tables: the spawn pad and the Heartstone. */
export const EXTRA_GLB: Readonly<Record<'spawn' | 'heartstone', GlbUnit>> = {
  // a portal pad on the first road tile
  spawn: {
    parts: [
      {
        file: 'tower-defense-kit/spawn-round.glb',
        scale: 1.4,
        position: [0, 0.1, 0],
      },
    ],
  },
  // a large crystal on the last road tile, tinted Heartstone green
  heartstone: {
    parts: [
      {
        file: 'tower-defense-kit/detail-crystal-large.glb',
        scale: 1.5,
        position: [0, 0.1, 0],
      },
    ],
    tint: pastel(PALETTE.heartstone),
  },
};
