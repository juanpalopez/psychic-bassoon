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

const KIT = 'tower-defense-kit/';

/** Mixes a colour halfway to white, so the kit's texture still shows. */
function pastel(hex: number): number {
  const channel = (shift: number) =>
    Math.round((((hex >> shift) & 255) + 255) / 2);
  return (channel(16) << 16) | (channel(8) << 8) | channel(0);
}

/** A piece and the height (before scaling) its origin sits at. */
type Piece = readonly [file: string, y: number, x?: number, z?: number];

/** Stacks Tower Defense Kit pieces, scaled together so a tower fits a cell. */
function stack(
  scale: number,
  pieces: readonly Piece[],
  tower: TowerId
): GlbUnit {
  return {
    // The kit has one palette, so each tower is tinted toward its colour.
    tint: pastel(PALETTE.towers[tower]),
    parts: pieces.map(([file, y, x = 0, z = 0]) => ({
      file: `${KIT}${file}.glb`,
      position: [x * scale, y * scale, z * scale] as const,
      scale,
    })),
  };
}

// Each level adds a section, so the level reads from the height alone.
// Piece heights (scale 1): base 0.21, bottom 0.6, top 0.5, weapons about 0.44.
export const TOWER_GLB: Readonly<
  Partial<Record<TowerId, (level: number) => GlbUnit>>
> = {
  ballista: level =>
    stack(
      0.85,
      [
        level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-a', 0],
        ...(level === 2 ? ([['tower-round-top-a', 0.6]] as Piece[]) : []),
        ['weapon-ballista', [0.21, 0.6, 1.1][level] ?? 0.21],
      ],
      'ballista'
    ),
  catapult: level =>
    stack(
      0.85,
      [
        level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-b', 0],
        ...(level === 2 ? ([['tower-round-top-b', 0.6]] as Piece[]) : []),
        ['weapon-catapult', [0.21, 0.6, 1.1][level] ?? 0.21],
      ],
      'catapult'
    ),
  frostSpire: level => {
    const top = [0.21, 0.6, 1.1][level] ?? 0.21;
    return stack(
      0.85,
      [
        level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-b', 0],
        ...(level === 2 ? ([['tower-round-top-b', 0.6]] as Piece[]) : []),
        ['detail-crystal-large', top],
        ...(level >= 1
          ? ([
              ['detail-crystal', top, 0.3, 0.2],
              ['detail-crystal', top, -0.3, 0.2],
            ] as Piece[])
          : []),
        ...(level === 2
          ? ([
              ['detail-crystal', top, 0.2, -0.3],
              ['detail-crystal', top, -0.2, -0.3],
            ] as Piece[])
          : []),
      ],
      'frostSpire'
    );
  },
  stormSpire: level =>
    stack(
      0.7,
      [
        level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-c', 0],
        ...(level === 2 ? ([['tower-round-top-a', 0.6]] as Piece[]) : []),
        ['tower-round-roof-c', [0.21, 0.6, 1.1][level] ?? 0.21],
      ],
      'stormSpire'
    ),
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
