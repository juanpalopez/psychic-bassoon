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
  scamp: {parts: [{file: 'mini-dungeon/character-orc.glb', scale: 0.7}]},
  raider: {parts: [{file: 'mini-dungeon/character-human.glb', scale: 0.95}]},
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

export const TOWER_GLB: Readonly<
  Partial<Record<TowerId, (level: number) => GlbUnit>>
> = {};
