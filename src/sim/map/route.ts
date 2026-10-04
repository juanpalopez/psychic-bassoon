import {RULES} from '../../content';
import type {Cell} from './mapgen';

/** A position on the board, in cells. */
export interface Point {
  readonly x: number;
  readonly y: number;
}

/** The line robots walk: spawn point, then every path cell centre. */
export interface Route {
  readonly points: readonly Point[];
  /** Distance from the spawn point to each point. */
  readonly cumulative: readonly number[];
  readonly total: number;
}

/**
 * Only +, -, * and sqrt are used for distances: they are exactly rounded, so
 * every JavaScript engine gives the same bits and replays stay identical.
 */
export function distance(a: Point, b: Point): number {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  return Math.sqrt(dx * dx + dy * dy);
}

export function buildRoute(path: readonly Cell[]): Route {
  const first = path[0];
  if (!first) throw new Error('a route needs at least one cell');
  const points: Point[] = [
    {x: first.col + RULES.cellCentre, y: -RULES.spawnOffset},
    ...path.map(c => ({
      x: c.col + RULES.cellCentre,
      y: c.row + RULES.cellCentre,
    })),
  ];
  const cumulative = [0];
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    if (!a || !b) throw new Error('unreachable');
    cumulative.push((cumulative[i - 1] ?? 0) + distance(a, b));
  }
  return {points, cumulative, total: cumulative[cumulative.length - 1] ?? 0};
}

/** Position `along` cells from the spawn point, clamped to the route. */
export function positionAt(route: Route, along: number): Point {
  const {points, cumulative} = route;
  let i = 0;
  while (i < cumulative.length - 2 && (cumulative[i + 1] ?? 0) < along) i++;
  const a = points[i];
  const b = points[i + 1];
  if (!a || !b) throw new Error('route has no segment');
  const start = cumulative[i] ?? 0;
  const length = (cumulative[i + 1] ?? 0) - start;
  const f = length > 0 ? Math.min(1, Math.max(0, (along - start) / length)) : 0;
  return {x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f};
}
