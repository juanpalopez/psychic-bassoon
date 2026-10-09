import {RULES, TOWER_IDS, TOWERS} from '../../content';
import type {Command, GameState} from '../game';
import type {Cell, GameMap} from '../map';
import {run} from './replay';
import type {RunResult} from './replay';

/** The bot acts once a second. */
const ACT_EVERY_TICKS = RULES.tickRate;

const EARLY_CALL_SECONDS = 5;
const EARLY_CALL_EVERY_WAVES = 4;
const SELL_SECONDS = 7;
const SELL_ABOVE_TOWERS = 20;

/**
 * Plots ordered by how much of the route a level-1 Ballista would cover, best
 * first, then reading order. Uses squared distances, so no rounding drift.
 */
export function rankPlots(map: GameMap): Cell[] {
  const reach = TOWERS.ballista.range[0] ?? 0;
  const scored: {cell: Cell; covered: number}[] = [];
  map.tiles.forEach((line, row) =>
    line.forEach((tile, col) => {
      if (tile !== 'plot') return;
      const covered = map.path.filter(p => {
        const dx = p.col - col;
        const dy = p.row - row;
        return dx * dx + dy * dy <= reach * reach;
      }).length;
      scored.push({cell: {col, row}, covered});
    })
  );
  return scored
    .sort(
      (a, b) =>
        b.covered - a.covered ||
        a.cell.row - b.cell.row ||
        a.cell.col - b.cell.col
    )
    .map(s => s.cell);
}

/**
 * A scripted player: once a second it launches the next wave when the field
 * is clear, otherwise builds the next tower type on the best free plot, or
 * upgrades the lowest-level tower. It only reads the game, like a UI would.
 */
export function createBot(map: GameMap): (game: GameState) => Command[] {
  const plots = rankPlots(map);
  return game => {
    if (game.tick % ACT_EVERY_TICKS !== 0) return [];
    if (!game.running) return [{type: 'launchWave'}];
    // During every 4th wave, try to call the next one early every 5 s. While foes are still being
    // released the sim rejects it, so replays also cover a rejected command.
    if (
      game.wave % EARLY_CALL_EVERY_WAVES === 0 &&
      game.tick % (EARLY_CALL_SECONDS * ACT_EVERY_TICKS) === 0
    ) {
      return [{type: 'launchWave'}];
    }
    // Every 7 s, once the field is crowded, sell the newest tower.
    const newest = game.towers.at(-1);
    if (
      newest &&
      game.towers.length > SELL_ABOVE_TOWERS &&
      game.tick % (SELL_SECONDS * ACT_EVERY_TICKS) === 0
    ) {
      return [{type: 'sell', towerId: newest.id}];
    }
    const type = TOWER_IDS[game.towers.length % TOWER_IDS.length];
    const free = plots.find(
      c => !game.towers.some(t => t.col === c.col && t.row === c.row)
    );
    if (type && free && game.gold >= TOWERS[type].cost[0]) {
      return [{type: 'build', tower: type, ...free}];
    }
    const weakest = [...game.towers]
      .filter(t => t.level < RULES.towerLevels - 1)
      .sort((a, b) => a.level - b.level || a.id - b.id)[0];
    if (weakest) return [{type: 'upgrade', towerId: weakest.id}];
    return [];
  };
}

/** Plays a whole game with the scripted player, recording what it did. */
export function playBot(seed: number, ticks: number): RunResult {
  let bot: ((game: GameState) => Command[]) | undefined;
  return run(seed, ticks, game => {
    bot ??= createBot(game.map);
    return bot(game);
  });
}
