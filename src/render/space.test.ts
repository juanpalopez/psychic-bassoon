import {describe, expect, it} from 'vitest';
import {GRID, RULES} from '../content';
import {
  cellCentreWorld,
  headingFromSim,
  simCellAt,
  worldFromSim,
  WORLD_TURN,
} from './space';

describe('landscape mapping', () => {
  it('runs the road left to right: sim rows become world x', () => {
    expect(worldFromSim(2.5, 0).x).toBe(0);
    expect(worldFromSim(2.5, GRID.rows).x).toBe(GRID.rows);
  });

  it('puts sim column 0 nearest the camera (world z = cols) and the last far', () => {
    expect(worldFromSim(0, 3).z).toBe(GRID.cols);
    expect(worldFromSim(GRID.cols, 3).z).toBe(0);
  });

  it('is a rotation, not a mirror: the sim x axis points to -z, y to +x', () => {
    const o = worldFromSim(3, 3);
    const dx = worldFromSim(4, 3);
    const dy = worldFromSim(3, 4);
    expect([dx.x - o.x, dx.z - o.z]).toEqual([0, -1]);
    expect([dy.x - o.x, dy.z - o.z]).toEqual([1, 0]);
  });

  it('gives each cell a centre inside its own world cell', () => {
    for (let row = 0; row < GRID.rows; row++) {
      for (let col = 0; col < GRID.cols; col++) {
        const c = cellCentreWorld(col, row);
        expect(Math.floor(c.x)).toBe(row);
        expect(Math.floor(c.z)).toBe(GRID.cols - 1 - col);
        expect(simCellAt(c.x, c.z)).toEqual({col, row});
      }
    }
  });

  it('turns tiles a quarter, so tile shapes keep their sides', () => {
    expect(WORLD_TURN).toBeCloseTo(Math.PI / 2, 12);
  });

  it('faces the way a foe walks: down the board (sim +y) is world +x', () => {
    // heading 0 faces +z, so +x is a quarter turn
    expect(headingFromSim(0, 1)).toBeCloseTo(Math.PI / 2, 12);
    // sim +x (a column to the right) is world -z, a half turn
    expect(Math.abs(headingFromSim(1, 0))).toBeCloseTo(Math.PI, 12);
    expect(RULES.cellCentre).toBe(0.5);
  });
});
