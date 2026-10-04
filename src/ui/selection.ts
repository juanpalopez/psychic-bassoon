import type {TowerId} from '../content';
import type {Command, GameState} from '../sim';

/** What the player has tapped: nothing, a free plate, or a tower. */
export type Selection =
  | {readonly kind: 'none'}
  | {readonly kind: 'plate'; readonly col: number; readonly row: number}
  | {readonly kind: 'tower'; readonly id: number};

const NONE: Selection = {kind: 'none'};

/** The selection a tap on a board cell makes. */
export function selectAt(
  game: GameState,
  cell: {col: number; row: number} | undefined
): Selection {
  if (!cell) return NONE;
  const tower = game.towers.find(t => t.col === cell.col && t.row === cell.row);
  if (tower) return {kind: 'tower', id: tower.id};
  if (game.map.tiles[cell.row]?.[cell.col] === 'plate') {
    return {kind: 'plate', col: cell.col, row: cell.row};
  }
  return NONE;
}

/** Keeps a selection valid after the game changes (a sale, a new tower). */
export function reconcileSelection(
  game: GameState,
  selection: Selection
): Selection {
  if (selection.kind === 'tower') {
    return game.towers.some(t => t.id === selection.id) ? selection : NONE;
  }
  if (selection.kind === 'plate') {
    return selectAt(game, selection);
  }
  return selection;
}

/** UI intent to command. The sim decides whether it is allowed. */
export function buildCommand(
  selection: Selection,
  tower: TowerId
): Command | undefined {
  if (selection.kind !== 'plate') return undefined;
  return {type: 'build', tower, col: selection.col, row: selection.row};
}

export function upgradeCommand(selection: Selection): Command | undefined {
  if (selection.kind !== 'tower') return undefined;
  return {type: 'upgrade', towerId: selection.id};
}

export function sellCommand(selection: Selection): Command | undefined {
  if (selection.kind !== 'tower') return undefined;
  return {type: 'sell', towerId: selection.id};
}
