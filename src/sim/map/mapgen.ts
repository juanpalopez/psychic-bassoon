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

/** The generated board: the foes' routes and the grid they sit on. */
export interface GameMap {
  readonly seed: number;
  /** The main road in walking order, from the spawn row to the Heartstone. */
  readonly path: readonly Cell[];
  /**
   * Every route from the spawn to the Heartstone. `routes[0]` is `path`; a
   * second one leaves the main road, runs beside it and rejoins it.
   */
  readonly routes: readonly (readonly Cell[])[];
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

const keyOf = (c: Cell) => `${c.col},${c.row}`;
const gap = (a: Cell, b: Cell) =>
  Math.abs(a.col - b.col) + Math.abs(a.row - b.row);

/** A way to grow a second route beside a straight stretch of the main road. */
interface Detour {
  /** Index in the main path where the detour leaves and where it rejoins. */
  readonly from: number;
  readonly to: number;
  /** The cells walked on the detour, in order, not including `from` or `to`. */
  readonly cells: readonly Cell[];
}

/**
 * Every detour that fits: a straight run of `detourMinRun` or more cells is
 * paralleled `detourOffset` cells to one side, joined by a one-cell connector
 * at each end (so a plot is left between the roads). It must stay on the
 * board and never touch the main road except at its two joins.
 */
function detourCandidates(path: readonly Cell[]): Detour[] {
  const onPath = new Set(path.map(keyOf));
  const out: Detour[] = [];
  let start = 0;
  for (let i = 1; i <= path.length; i++) {
    const a = path[i - 1];
    const b = path[i];
    const c = path[start];
    const next = path[start + 1];
    if (!a || !c || !next) continue;
    const alongCol = next.col === c.col; // true: a vertical run
    const continues =
      b !== undefined &&
      (alongCol ? b.col === c.col : b.row === c.row) &&
      gap(a, b) === 1;
    if (continues) continue;
    // the run is path[start .. i - 1]
    if (i - start >= MAP.detourMinRun) {
      for (const side of [-1, 1]) {
        for (let from = start + 1; from <= i - 4; from++) {
          for (let to = from + 2; to <= i - 2; to++) {
            const cells: Cell[] = [];
            const shift = (cell: Cell, by: number): Cell =>
              alongCol
                ? {col: cell.col + side * by, row: cell.row}
                : {col: cell.col, row: cell.row + side * by};
            const first = path[from];
            const last = path[to];
            if (!first || !last) continue;
            cells.push(shift(first, 1));
            for (let k = from; k <= to; k++) {
              const cell = path[k];
              if (cell) cells.push(shift(cell, MAP.detourOffset));
            }
            cells.push(shift(last, 1));
            const inside = cells.every(
              d =>
                d.col >= 0 &&
                d.col < GRID.cols &&
                d.row >= 0 &&
                d.row < GRID.rows
            );
            const clear = cells.every((d, n) => {
              if (onPath.has(keyOf(d))) return false;
              return path.every(m => {
                const g = gap(d, m);
                const joins =
                  (n === 0 && m === first) ||
                  (n === cells.length - 1 && m === last);
                return g >= 2 || (g === 1 && joins);
              });
            });
            if (inside && clear) out.push({from, to, cells});
          }
        }
      }
    }
    // a corner cell ends one run and starts the next
    start = i - 1;
  }
  return out;
}

/** Picks one detour (from the map's own stream) and returns the second route. */
function addDetour(path: readonly Cell[], rng: Rng): Cell[] | undefined {
  const candidates = detourCandidates(path);
  if (candidates.length === 0) return undefined;
  const pick = candidates[nextInt(rng, candidates.length)];
  if (!pick) return undefined;
  return [
    ...path.slice(0, pick.from + 1),
    ...pick.cells,
    ...path.slice(pick.to),
  ];
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
      const detour = addDetour(path, rng);
      const routes = detour ? [path, detour] : [path];
      const tiles: Tile[][] = Array.from({length: GRID.rows}, () =>
        new Array<Tile>(GRID.cols).fill('plot')
      );
      for (const {col, row} of routes.flat()) {
        const line = tiles[row];
        if (line) line[col] = 'road';
      }
      return {seed, path, routes, tiles};
    }
  }
  throw new Error(`no valid map for seed ${seed} in ${MAP.maxAttempts} tries`);
}
