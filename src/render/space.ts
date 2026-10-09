import {GRID, RULES} from '../content';

/**
 * The game is played in landscape, so the board is drawn turned a quarter:
 * the sim's rows run left to right (the road from the spawn on the left to
 * the Heartstone on the right) and its columns run toward the camera.
 * It is a rotation, not a mirror. The sim itself is untouched; this is the
 * one place that knows about the turn.
 *
 * world x = sim y (row), world z = cols - sim x (col).
 */
export const WORLD_TURN = Math.PI / 2;

/** World size of the board: rows run along x, columns along z. */
export const BOARD_WORLD = {width: GRID.rows, depth: GRID.cols} as const;

export function worldFromSim(
  simX: number,
  simY: number
): {x: number; z: number} {
  return {x: simY, z: GRID.cols - simX};
}

/** Centre of a board cell, in world space. */
export function cellCentreWorld(
  col: number,
  row: number
): {x: number; z: number} {
  return worldFromSim(col + RULES.cellCentre, row + RULES.cellCentre);
}

/** The board cell under a world point (may be outside the board). */
export function simCellAt(
  worldX: number,
  worldZ: number
): {col: number; row: number} {
  return {col: Math.floor(GRID.cols - worldZ), row: Math.floor(worldX)};
}

/** Heading (0 faces +z) for a step of (dx, dy) in sim coordinates. */
export function headingFromSim(dx: number, dy: number): number {
  const stepX = dy; // world x
  const stepZ = -dx; // world z
  return Math.atan2(stepX, stepZ);
}
