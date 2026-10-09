import {GRID, MAP} from '../../content';
import {deriveRng, nextInt} from '../rng';
import type {Rng} from '../rng';
import {RNG_STREAMS} from '../streams';

/** A board cell, counted from the top-left corner. */
export interface Cell {
  readonly col: number;
  readonly row: number;
}

/** `plot` cells accept a tower; `road` cells carry the foes. */
export type Tile = 'road' | 'plot';

/** The generated board: the foes' route and the grid it sits on. */
export interface GameMap {
  readonly seed: number;
  /** Route cells in walking order, from the spawn row to the Heartstone. */
  readonly path: readonly Cell[];
  readonly tiles: readonly (readonly Tile[])[];
}

function tryPath(rng: Rng): Cell[] | undefined {
  let col = MAP.startMargin + nextInt(rng, GRID.cols - 2 * MAP.startMargin);
  let row = 0;
  const cells: Cell[] = [{col, row}];
  while (row < GRID.rows - 1) {
    const run = Math.min(
      MAP.minRunDown + nextInt(rng, MAP.runDownVariance),
      GRID.rows - 1 - row
    );
    for (let i = 0; i < run; i++) {
      row++;
      cells.push({col, row});
    }
    if (row >= GRID.rows - 1) break;
    let target: number;
    do {
      target = nextInt(rng, GRID.cols);
    } while (Math.abs(target - col) < MAP.minTurnColumns);
    const step = Math.sign(target - col);
    while (col !== target) {
      col += step;
      cells.push({col, row});
    }
  }
  return cells.length >= GRID.rows + MAP.minExtraCells ? cells : undefined;
}

/**
 * Builds the board for a seed. The same seed always gives the same map: it
 * draws only from its own stream, so other subsystems cannot shift it.
 */
export function generateMap(seed: number): GameMap {
  const rng = deriveRng(seed, RNG_STREAMS.map);
  for (let attempt = 0; attempt < MAP.maxAttempts; attempt++) {
    const path = tryPath(rng);
    if (path) {
      const tiles: Tile[][] = Array.from({length: GRID.rows}, () =>
        new Array<Tile>(GRID.cols).fill('plot')
      );
      for (const {col, row} of path) {
        const line = tiles[row];
        if (line) line[col] = 'road';
      }
      return {seed, path, tiles};
    }
  }
  throw new Error(`no valid map for seed ${seed} in ${MAP.maxAttempts} tries`);
}
