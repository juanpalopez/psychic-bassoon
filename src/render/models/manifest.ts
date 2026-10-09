import type {EnemyId, TowerId} from '../../content';

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

/** A piece and the height (before scaling) its origin sits at. */
type Piece = readonly [file: string, y: number, x?: number, z?: number];

/** Stacks Tower Defense Kit pieces, scaled together so a tower fits a cell. */
function stack(scale: number, pieces: readonly Piece[]): GlbUnit {
  return {
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
    stack(0.85, [
      level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-a', 0],
      ...(level === 2 ? ([['tower-round-top-a', 0.6]] as Piece[]) : []),
      ['weapon-ballista', [0.21, 0.6, 1.1][level] ?? 0.21],
    ]),
  catapult: level =>
    stack(0.85, [
      level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-b', 0],
      ...(level === 2 ? ([['tower-round-top-b', 0.6]] as Piece[]) : []),
      ['weapon-catapult', [0.21, 0.6, 1.1][level] ?? 0.21],
    ]),
  frostSpire: level => {
    const top = [0.21, 0.6, 1.1][level] ?? 0.21;
    return stack(0.85, [
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
    ]);
  },
  stormSpire: level =>
    stack(0.7, [
      level === 0 ? ['tower-round-base', 0] : ['tower-round-bottom-c', 0],
      ...(level === 2 ? ([['tower-round-top-a', 0.6]] as Piece[]) : []),
      ['tower-round-roof-c', [0.21, 0.6, 1.1][level] ?? 0.21],
    ]),
};
