import {describe, expect, it} from 'vitest';
import {RULES} from '../../content';
import {generateMap} from './mapgen';
import {buildRoute, positionAt} from './route';

describe('route', () => {
  const map = generateMap(42);
  const route = buildRoute(map.path);
  const first = map.path[0];
  const last = map.path.at(-1);
  if (!first || !last) throw new Error('empty path');

  it('starts above the top row, in the centre of the first column', () => {
    expect(route.points[0]).toEqual({
      x: first.col + RULES.cellCentre,
      y: -RULES.spawnOffset,
    });
  });

  it('then visits the centre of every path cell in order', () => {
    expect(route.points.slice(1)).toEqual(
      map.path.map(c => ({
        x: c.col + RULES.cellCentre,
        y: c.row + RULES.cellCentre,
      }))
    );
  });

  it('measures its length from the spawn point to the Heartstone', () => {
    const expected =
      RULES.spawnOffset + RULES.cellCentre + (map.path.length - 1);
    expect(route.total).toBeCloseTo(expected, 9);
  });

  it('finds the position at a distance', () => {
    expect(positionAt(route, 0)).toEqual(route.points[0]);
    expect(positionAt(route, route.total)).toEqual({
      x: last.col + RULES.cellCentre,
      y: last.row + RULES.cellCentre,
    });
    // the first segment runs straight down from the spawn point
    const half = positionAt(route, 0.475);
    expect(half.x).toBe(first.col + RULES.cellCentre);
    expect(half.y).toBeCloseTo(0.025, 9);
  });

  it('stays on the last point past the end', () => {
    expect(positionAt(route, route.total + 5)).toEqual(
      positionAt(route, route.total)
    );
  });
});
