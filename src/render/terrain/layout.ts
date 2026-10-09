import {GRID} from '../../content';
import {deriveRng, nextInt, RNG_STREAMS} from '../../sim';
import type {GameMap} from '../../sim';

export type Side = 'N' | 'E' | 'S' | 'W';

/** Kenney Tower Defense Kit tiles used for the ground, and the scenery mix. */
export const TERRAIN = {
  grass: 'tower-defense-kit/tile.glb',
  straight: 'tower-defense-kit/tile-straight.glb',
  corner: 'tower-defense-kit/tile-corner-square.glb',
  end: 'tower-defense-kit/tile-end.glb',
  /** Cells of scenery around the board; more above, where the camera looks. */
  margin: {top: 7, side: 3, bottom: 2},
  /** Beyond this many cells from the board only cheap scenery is used. */
  nearCells: 2,
  /** The scenery stream (see `RNG_STREAMS`): render-only. */
  stream: RNG_STREAMS.scenery,
  /** Cheap, sparse scenery for the far field (triangle budget). */
  farScenery: [
    {file: 'tower-defense-kit/tile.glb', weight: 80},
    {file: 'tower-defense-kit/tile-tree.glb', weight: 15},
    {file: 'tower-defense-kit/tile-hill.glb', weight: 5},
  ],
  /** Weighted scenery tiles for the ring close to the board. */
  scenery: [
    {file: 'tower-defense-kit/tile.glb', weight: 42},
    {file: 'tower-defense-kit/tile-tree.glb', weight: 28},
    {file: 'tower-defense-kit/tile-tree-double.glb', weight: 6},
    {file: 'tower-defense-kit/tile-rock.glb', weight: 9},
    {file: 'tower-defense-kit/tile-hill.glb', weight: 7},
    {file: 'tower-defense-kit/tile-crystal.glb', weight: 5},
    {file: 'tower-defense-kit/tile-tree-quad.glb', weight: 3},
  ],
} as const;

/** Every file the terrain needs; if one fails to load the primitive map is used. */
export const TERRAIN_FILES: readonly string[] = [
  ...new Set([
    TERRAIN.grass,
    TERRAIN.straight,
    TERRAIN.corner,
    TERRAIN.end,
    ...TERRAIN.scenery.map(s => s.file),
    ...TERRAIN.farScenery.map(s => s.file),
  ]),
];

export interface Placement {
  readonly file: string;
  readonly col: number;
  readonly row: number;
  /** Radians about the vertical axis. */
  readonly rotationY: number;
}

const QUARTER = Math.PI / 2;

/**
 * The sides each Kenney road tile opens at when not turned (read from the
 * recessed road in the models): straight N-S, corner E-S, end S.
 */
const BASE_SIDES: Readonly<Record<string, readonly Side[]>> = {
  [TERRAIN.straight]: ['N', 'S'],
  [TERRAIN.corner]: ['E', 'S'],
  [TERRAIN.end]: ['S'],
};

// Turning by a quarter (about Y, counter-clockwise from above) takes
// S to E, E to N, N to W and W to S.
const TURN: Readonly<Record<Side, Side>> = {S: 'E', E: 'N', N: 'W', W: 'S'};

/** Which sides a road tile opens at after turning it by `rotationY`. */
export function openSides(file: string, rotationY: number): Side[] {
  const quarters = ((Math.round(rotationY / QUARTER) % 4) + 4) % 4;
  return (BASE_SIDES[file] ?? []).map(side => {
    let s = side;
    for (let i = 0; i < quarters; i++) s = TURN[s];
    return s;
  });
}

const key = (cell: {col: number; row: number}) => `${cell.col},${cell.row}`;

function sideTo(
  from: {col: number; row: number},
  to: {col: number; row: number}
): Side {
  if (to.col > from.col) return 'E';
  if (to.col < from.col) return 'W';
  return to.row > from.row ? 'S' : 'N';
}

/** Finds the tile and quarter turn that opens at exactly these sides. */
function fit(wanted: readonly Side[]): {file: string; rotationY: number} {
  const target = [...wanted].sort().join('');
  for (const file of Object.keys(BASE_SIDES)) {
    for (let q = 0; q < 4; q++) {
      const have = [...openSides(file, q * QUARTER)].sort().join('');
      if (have === target) return {file, rotationY: q * QUARTER};
    }
  }
  throw new Error(`no road tile opens at ${target}`);
}

/** One road tile per route cell, turned to meet its neighbours. */
export function roadPlacements(map: GameMap): Placement[] {
  return map.path.map((cell, i) => {
    const neighbours = [map.path[i - 1], map.path[i + 1]].filter(
      (c): c is {col: number; row: number} => c !== undefined
    );
    const {file, rotationY} = fit(neighbours.map(n => sideTo(cell, n)));
    return {file, col: cell.col, row: cell.row, rotationY};
  });
}

/** Grass under every plot. Flat, so a tower always stands level. */
export function grassPlacements(map: GameMap): Placement[] {
  const roads = new Set(map.path.map(key));
  const out: Placement[] = [];
  map.tiles.forEach((line, row) =>
    line.forEach((tile, col) => {
      if (tile === 'plot' && !roads.has(key({col, row}))) {
        out.push({file: TERRAIN.grass, col, row, rotationY: 0});
      }
    })
  );
  return out;
}

export interface Margins {
  readonly top: number;
  readonly side: number;
  readonly bottom: number;
}

function pickWeighted(
  table: readonly {readonly file: string; readonly weight: number}[],
  roll: number
): string {
  let left = roll;
  for (const item of table) {
    if (left < item.weight) return item.file;
    left -= item.weight;
  }
  return table[0]?.file ?? TERRAIN.grass;
}

/** Trees, rocks and hills around the board, from the map's seed. */
export function sceneryPlacements(
  seed: number,
  margin: Margins,
  avoid: readonly {col: number; row: number}[] = []
): Placement[] {
  const rng = deriveRng(seed, TERRAIN.stream);
  const out: Placement[] = [];
  for (let row = -margin.top; row < GRID.rows + margin.bottom; row++) {
    for (let col = -margin.side; col < GRID.cols + margin.side; col++) {
      if (col >= 0 && col < GRID.cols && row >= 0 && row < GRID.rows) continue;
      const away = Math.max(
        -col,
        col - (GRID.cols - 1),
        -row,
        row - (GRID.rows - 1)
      );
      const table =
        away > TERRAIN.nearCells ? TERRAIN.farScenery : TERRAIN.scenery;
      const total = table.reduce((sum, item) => sum + item.weight, 0);
      const file = pickWeighted(table, nextInt(rng, total));
      const rotationY = nextInt(rng, 4) * QUARTER;
      // keep the cell above the spawn plain grass: foes walk in through it
      const clear = avoid.some(a => a.col === col && a.row === row);
      out.push({file: clear ? TERRAIN.grass : file, col, row, rotationY});
    }
  }
  return out;
}
