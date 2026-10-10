import {describe, expect, it} from 'vitest';
import {GRID, MAP} from '../../content';
import {deriveRng, nextFloat} from '../rng';
import {RNG_STREAMS} from '../streams';
import {generateMap} from './mapgen';

const SEEDS = Array.from({length: 300}, (_, i) => i * 7919 + 1);

describe('generateMap', () => {
  it('is reproducible from its seed', () => {
    expect(generateMap(42)).toEqual(generateMap(42));
  });

  it('differs between seeds', () => {
    const paths = new Set(SEEDS.map(s => JSON.stringify(generateMap(s).path)));
    expect(paths.size).toBeGreaterThan(SEEDS.length * 0.9);
  });

  it.each([1, 42, 2024])(
    'follows the prototype algorithm literally for seed %i',
    seed => {
      // Prototype genPath(), verbatim, fed by the map stream's floats.
      const rng = deriveRng(seed, RNG_STREAMS.map);
      const random = () => nextFloat(rng);
      const COLS = 9;
      const ROWS = 13;
      let expected: [number, number][] = [];
      for (let a = 0; a < 300; a++) {
        let c = 1 + Math.floor(random() * (COLS - 2));
        let r = 0;
        const cells: [number, number][] = [[c, r]];
        while (r < ROWS - 1) {
          let down = 2 + Math.floor(random() * 2);
          if (r + down > ROWS - 1) down = ROWS - 1 - r;
          for (let i = 0; i < down; i++) {
            r++;
            cells.push([c, r]);
          }
          if (r >= ROWS - 1) break;
          let t: number;
          do {
            t = Math.floor(random() * COLS);
          } while (Math.abs(t - c) < 3);
          const s = Math.sign(t - c);
          while (c !== t) {
            c += s;
            cells.push([c, r]);
          }
        }
        if (cells.length >= ROWS + 16) {
          expected = cells;
          break;
        }
      }
      expect(generateMap(seed).path.map(p => [p.col, p.row])).toEqual(expected);
    }
  );

  it('keeps the map plain data that survives JSON', () => {
    const map = generateMap(5);
    expect(JSON.parse(JSON.stringify(map))).toEqual(map);
  });

  describe.each(SEEDS)('seed %i', seed => {
    const {path} = generateMap(seed);

    it('starts on the top row and ends on the bottom row', () => {
      expect(path[0]?.row).toBe(0);
      expect(path.at(-1)?.row).toBe(GRID.rows - 1);
    });

    it('starts inside the side margins', () => {
      const col = path[0]?.col ?? -1;
      expect(col).toBeGreaterThanOrEqual(MAP.startMargin);
      expect(col).toBeLessThan(GRID.cols - MAP.startMargin);
    });

    it('stays on the board', () => {
      for (const {col, row} of path) {
        expect(col).toBeGreaterThanOrEqual(0);
        expect(col).toBeLessThan(GRID.cols);
        expect(row).toBeGreaterThanOrEqual(0);
        expect(row).toBeLessThan(GRID.rows);
      }
    });

    it('moves one cell at a time, orthogonally', () => {
      for (let i = 1; i < path.length; i++) {
        const a = path[i - 1];
        const b = path[i];
        expect(
          Math.abs((a?.col ?? 0) - (b?.col ?? 0)) +
            Math.abs((a?.row ?? 0) - (b?.row ?? 0))
        ).toBe(1);
      }
    });

    it('never touches itself', () => {
      for (let i = 0; i < path.length; i++) {
        for (let j = i + 2; j < path.length; j++) {
          const a = path[i];
          const b = path[j];
          const gap =
            Math.abs((a?.col ?? 0) - (b?.col ?? 0)) +
            Math.abs((a?.row ?? 0) - (b?.row ?? 0));
          expect(gap).toBeGreaterThan(1);
        }
      }
    });

    it('is long enough to be worth defending', () => {
      expect(path.length).toBeGreaterThanOrEqual(GRID.rows + MAP.minExtraCells);
    });

    it('marks exactly the path cells as path in the grid', () => {
      const {tiles} = generateMap(seed);
      expect(tiles).toHaveLength(GRID.rows);
      let count = 0;
      tiles.forEach((line, row) => {
        expect(line).toHaveLength(GRID.cols);
        line.forEach((tile, col) => {
          const onPath = generateMap(seed)
            .routes.flat()
            .some(c => c.col === col && c.row === row);
          expect(tile).toBe(onPath ? 'road' : 'plot');
          if (tile === 'road') count++;
        });
      });
      expect(count).toBe(
        new Set(
          generateMap(seed)
            .routes.flat()
            .map(c => `${c.col},${c.row}`)
        ).size
      );
    });
  });
});

describe('detours (more than one route)', () => {
  const keyOf = (c: {col: number; row: number}) => `${c.col},${c.row}`;
  const manhattan = (
    a: {col: number; row: number},
    b: {col: number; row: number}
  ) => Math.abs(a.col - b.col) + Math.abs(a.row - b.row);

  it('keeps the main road first, unchanged by the detour', () => {
    for (const seed of SEEDS.slice(0, 50)) {
      const map = generateMap(seed);
      expect(map.routes[0]).toBe(map.path);
    }
  });

  describe.each(SEEDS.slice(0, 120))('seed %i', seed => {
    const map = generateMap(seed);
    const start = map.path[0];
    const end = map.path.at(-1);

    it('gives every route the same start and end, one orthogonal step at a time', () => {
      for (const route of map.routes) {
        expect(route[0]).toEqual(start);
        expect(route.at(-1)).toEqual(end);
        for (let i = 1; i < route.length; i++) {
          const a = route[i - 1];
          const b = route[i];
          expect(a && b && manhattan(a, b)).toBe(1);
        }
        expect(new Set(route.map(keyOf)).size).toBe(route.length);
      }
    });

    it('marks exactly the cells of all routes as road', () => {
      const roads = new Set(map.routes.flat().map(keyOf));
      let count = 0;
      map.tiles.forEach((line, row) =>
        line.forEach((tile, col) => {
          expect(tile === 'road').toBe(roads.has(keyOf({col, row})));
          if (tile === 'road') count++;
        })
      );
      expect(count).toBe(roads.size);
    });

    it('keeps a detour apart from the main road except where it leaves and rejoins', () => {
      const main = new Set(map.path.map(keyOf));
      for (const route of map.routes.slice(1)) {
        const own = route.filter(c => !main.has(keyOf(c)));
        expect(own.length).toBeGreaterThan(0);
        own.forEach((cell, i) => {
          for (const m of map.path) {
            const gap = manhattan(cell, m);
            const joins = (i === 0 || i === own.length - 1) && gap === 1;
            expect(gap >= 2 || joins).toBe(true);
          }
        });
        // it leaves the main road once and rejoins it once
        const shared = route.map(c => main.has(keyOf(c)));
        const changes = shared.filter((v, i) => i > 0 && v !== shared[i - 1]);
        expect(changes).toHaveLength(2);
      }
    });
  });

  it('adds a detour to most maps, and never more than one', () => {
    const counts = SEEDS.map(s => generateMap(s).routes.length);
    expect(Math.max(...counts)).toBe(2);
    expect(counts.filter(n => n === 2).length).toBeGreaterThan(
      SEEDS.length * 0.6
    );
  });

  it('is reproducible', () => {
    expect(generateMap(77).routes).toEqual(generateMap(77).routes);
  });
});
