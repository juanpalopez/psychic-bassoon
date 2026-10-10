import {describe, expect, it} from 'vitest';
import {GRID} from '../../content';
import {deriveRng, generateMap, RNG_STREAMS} from '../../sim';
import type {GameMap} from '../../sim';
import {
  grassPlacements,
  openSides,
  roadPlacements,
  sceneryPlacements,
  TERRAIN,
} from './layout';
import type {Margins, Side} from './layout';

function mapOf(path: [number, number][], cols = 5, rows = 5): GameMap {
  const cells = path.map(([col, row]) => ({col, row}));
  return {
    seed: 0,
    path: cells,
    routes: [cells],
    tiles: Array.from({length: rows}, (_, row) =>
      Array.from({length: cols}, (_, col) =>
        cells.some(c => c.col === col && c.row === row) ? 'road' : 'plot'
      )
    ),
  };
}

const sides = (list: Side[]) => [...list].sort();

describe('openSides', () => {
  it('knows which sides each kit tile opens at each turn', () => {
    expect(sides(openSides(TERRAIN.straight, 0))).toEqual(['N', 'S']);
    expect(sides(openSides(TERRAIN.straight, Math.PI / 2))).toEqual(['E', 'W']);
    expect(sides(openSides(TERRAIN.corner, 0))).toEqual(['E', 'S']);
    expect(sides(openSides(TERRAIN.corner, Math.PI / 2))).toEqual(['E', 'N']);
    expect(sides(openSides(TERRAIN.corner, Math.PI))).toEqual(['N', 'W']);
    expect(sides(openSides(TERRAIN.corner, (3 * Math.PI) / 2))).toEqual([
      'S',
      'W',
    ]);
    expect(openSides(TERRAIN.end, 0)).toEqual(['S']);
    expect(openSides(TERRAIN.end, Math.PI)).toEqual(['N']);
  });
});

describe('roadPlacements', () => {
  it('uses straights, corners and two ends for a bent road', () => {
    // down column 1, across row 2, down column 3
    const map = mapOf([
      [1, 0],
      [1, 1],
      [1, 2],
      [2, 2],
      [3, 2],
      [3, 3],
      [3, 4],
    ]);
    const files = roadPlacements(map).map(p => p.file);
    expect(files).toEqual([
      TERRAIN.end,
      TERRAIN.straight,
      TERRAIN.corner,
      TERRAIN.straight,
      TERRAIN.corner,
      TERRAIN.straight,
      TERRAIN.end,
    ]);
  });

  it('turns tiles as hand-checked for a small bend (not derived from openSides)', () => {
    // (1,0) down to (1,1), then east to (2,1)
    const map = mapOf([
      [1, 0],
      [1, 1],
      [2, 1],
    ]);
    const quarter = Math.PI / 2;
    expect(roadPlacements(map).map(p => [p.file, p.rotationY])).toEqual([
      [TERRAIN.end, 0], // end opens S, toward (1,1)
      [TERRAIN.corner, quarter], // N and E
      [TERRAIN.end, 3 * quarter], // end opens W, toward (1,1)
    ]);
  });

  it('places each tile on its own cell', () => {
    const map = mapOf([
      [1, 0],
      [1, 1],
      [2, 1],
    ]);
    expect(roadPlacements(map).map(p => [p.col, p.row])).toEqual([
      [1, 0],
      [1, 1],
      [2, 1],
    ]);
  });

  it('opens every tile toward exactly its road neighbours, on 200 seeds', () => {
    for (let seed = 1; seed <= 200; seed++) {
      const map = generateMap(seed * 7919);
      const placements = roadPlacements(map);
      const roads = new Set(map.routes.flat().map(c => `${c.col},${c.row}`));
      expect(placements).toHaveLength(roads.size);
      for (const p of placements) {
        const want: Side[] = [];
        if (roads.has(`${p.col},${p.row - 1}`)) want.push('N');
        if (roads.has(`${p.col + 1},${p.row}`)) want.push('E');
        if (roads.has(`${p.col},${p.row + 1}`)) want.push('S');
        if (roads.has(`${p.col - 1},${p.row}`)) want.push('W');
        expect(sides(openSides(p.file, p.rotationY))).toEqual(sides(want));
      }
    }
  });

  it('draws a T tile at each end of a detour, and only there', () => {
    for (let seed = 1; seed <= 100; seed++) {
      const map = generateMap(seed * 104729);
      const tees = roadPlacements(map).filter(p => p.file === TERRAIN.split);
      expect(tees).toHaveLength(map.routes.length > 1 ? 2 : 0);
    }
  });
});

describe('grassPlacements', () => {
  it('covers every plot and nothing else', () => {
    const map = generateMap(42);
    const grass = grassPlacements(map);
    const plots = map.tiles.flat().filter(t => t === 'plot').length;
    expect(grass).toHaveLength(plots);
    for (const g of grass) {
      expect(map.tiles[g.row]?.[g.col]).toBe('plot');
      expect(g.file).toBe(TERRAIN.grass);
    }
  });
});

describe('sceneryPlacements', () => {
  const ring = (m: Margins) =>
    (GRID.cols + m.near + m.far) * (GRID.rows + m.spawn + m.heart) -
    GRID.cols * GRID.rows;

  it('fills the ring around the board and never the board itself', () => {
    const items = sceneryPlacements(42, TERRAIN.margin);
    expect(items).toHaveLength(ring(TERRAIN.margin));
    for (const it of items) {
      const inside =
        it.col >= 0 && it.col < GRID.cols && it.row >= 0 && it.row < GRID.rows;
      expect(inside).toBe(false);
      expect(it.col).toBeGreaterThanOrEqual(-TERRAIN.margin.near);
      expect(it.row).toBeGreaterThanOrEqual(-TERRAIN.margin.spawn);
    }
  });

  it('is the same for the same seed and different for another', () => {
    expect(sceneryPlacements(7, TERRAIN.margin)).toEqual(
      sceneryPlacements(7, TERRAIN.margin)
    );
    expect(sceneryPlacements(7, TERRAIN.margin)).not.toEqual(
      sceneryPlacements(8, TERRAIN.margin)
    );
  });

  it('uses only known scenery tiles and turns them in quarter turns', () => {
    for (const item of sceneryPlacements(99, TERRAIN.margin)) {
      expect(
        [...TERRAIN.scenery, ...TERRAIN.farScenery].map(s => s.file)
      ).toContain(item.file);
      expect((item.rotationY / (Math.PI / 2)) % 1).toBeCloseTo(0, 9);
    }
  });

  it('mixes grass, trees and rocks rather than one tile', () => {
    const files = new Set(
      sceneryPlacements(5, TERRAIN.margin).map(p => p.file)
    );
    expect(files.size).toBeGreaterThanOrEqual(4);
  });

  it('keeps the far field cheap: only grass, trees and hills beyond 2 cells', () => {
    const cheap = TERRAIN.farScenery.map(s => s.file);
    for (const p of sceneryPlacements(3, TERRAIN.margin)) {
      const away = Math.max(
        -p.col,
        p.col - (GRID.cols - 1),
        -p.row,
        p.row - (GRID.rows - 1)
      );
      if (away > TERRAIN.nearCells) expect(cheap).toContain(p.file);
    }
  });

  it('keeps the cells it is told to avoid as plain grass', () => {
    const avoid = [{col: 3, row: -1}];
    const items = sceneryPlacements(11, TERRAIN.margin, avoid);
    const cell = items.find(p => p.col === 3 && p.row === -1);
    expect(cell?.file).toBe(TERRAIN.grass);
    expect(items).toHaveLength(sceneryPlacements(11, TERRAIN.margin).length);
  });

  it('draws from its own random stream, not the map or wave streams', () => {
    // a render-only stream: using the sim's map stream would tie scenery to
    // the map and break if map generation changed
    const used = Object.values(RNG_STREAMS);
    expect(used.filter(n => n === TERRAIN.stream)).toHaveLength(1);
    expect(deriveRng(1, TERRAIN.stream).state).not.toBe(deriveRng(1, 0).state);
  });
});
