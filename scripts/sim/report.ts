import {RULES} from '../../src/content';
import {
  advanceClock,
  createBot,
  createClock,
  createRunner,
  fingerprint,
  generateMap,
  TICK_SECONDS,
} from '../../src/sim';
import type {GameMap, LoggedEvent} from '../../src/sim';

/** One line of the wave table. Fields are undefined if the wave never ended. */
export interface WaveRow {
  readonly wave: number;
  readonly spawned: number;
  readonly killed: number;
  readonly leaked: number;
  readonly lives: number | undefined;
  readonly credits: number | undefined;
  readonly towers: number | undefined;
}

/** The state of the game when a wave was cleared. */
export interface ClearSnapshot {
  readonly lives: number;
  readonly credits: number;
  readonly towers: number;
}

export interface Args {
  readonly seed: number;
  readonly waves: number;
  readonly speed: number;
}

const DEFAULT_ARGS: Args = {seed: 42, waves: 10, speed: 1};
const MAX_WAVES = 200;
/** Frame length used to drive the run, as a live game at 60 fps would. */
const FRAME_SECONDS = 1 / 60;
/** A run that has not ended after this many ticks is cut off (one hour). */
const MAX_TICKS = 3600 * RULES.tickRate;

export function parseArgs(argv: readonly string[]): Args {
  const values: Record<string, number> = {};
  const list = argv.filter(a => a !== '--');
  for (let i = 0; i < list.length; i++) {
    const [flag, inline] = (list[i] ?? '').split('=', 2);
    const name = flag?.replace(/^--/, '');
    if (!name || !(name in DEFAULT_ARGS) || !flag?.startsWith('--')) {
      throw new Error(`unknown option "${list[i]}"`);
    }
    const raw = inline ?? list[++i];
    const value = Number(raw);
    if (raw === undefined || raw === '' || !Number.isSafeInteger(value)) {
      throw new Error(`--${name} needs a whole number, got "${raw}"`);
    }
    values[name] = value;
  }
  const args = {...DEFAULT_ARGS, ...values};
  if (args.waves < 1 || args.waves > MAX_WAVES) {
    throw new Error(`--waves must be 1 to ${MAX_WAVES}`);
  }
  if (args.speed < 1 || args.speed > RULES.maxGameSpeed) {
    throw new Error(`--speed must be 1 to ${RULES.maxGameSpeed}`);
  }
  return args;
}

/** Draws the board: S spawn, C core, # belt, . plate. */
export function formatMap(map: GameMap): string {
  const first = map.path[0];
  const last = map.path.at(-1);
  return map.tiles
    .map((line, row) =>
      line
        .map((tile, col) => {
          if (first?.col === col && first.row === row) return 'S';
          if (last?.col === col && last.row === row) return 'C';
          return tile === 'path' ? '#' : '.';
        })
        .join('')
    )
    .join('\n');
}

const COLUMNS: [string, (row: WaveRow) => number | undefined][] = [
  ['Wave', r => r.wave],
  ['Spawned', r => r.spawned],
  ['Killed', r => r.killed],
  ['Leaked', r => r.leaked],
  ['Lives', r => r.lives],
  ['Credits', r => r.credits],
  ['Towers', r => r.towers],
];

export function formatTable(rows: readonly WaveRow[]): string {
  const cell = (value: number | undefined) =>
    value === undefined ? '-' : String(value);
  const widths = COLUMNS.map(([name, get]) =>
    Math.max(name.length, ...rows.map(r => cell(get(r)).length))
  );
  const line = (cells: string[]) =>
    cells.map((c, i) => c.padStart(widths[i] ?? 0)).join('  ');
  return [
    line(COLUMNS.map(([name]) => name)),
    ...rows.map(r => line(COLUMNS.map(([, get]) => cell(get(r))))),
  ].join('\n');
}

export function summarizeWaves(
  events: readonly LoggedEvent[],
  clears: ReadonlyMap<number, ClearSnapshot>
): WaveRow[] {
  const waveOf = new Map<number, number>();
  const rows = new Map<
    number,
    {spawned: number; killed: number; leaked: number}
  >();
  for (const {event} of events) {
    if (event.type === 'waveLaunched') {
      rows.set(event.wave, {spawned: 0, killed: 0, leaked: 0});
    } else if (event.type === 'enemySpawned') {
      waveOf.set(event.enemyId, event.wave);
      const row = rows.get(event.wave);
      if (row) row.spawned++;
    } else if (event.type === 'enemyKilled' || event.type === 'enemyLeaked') {
      const row = rows.get(waveOf.get(event.enemyId) ?? -1);
      if (!row) continue;
      if (event.type === 'enemyKilled') row.killed++;
      else row.leaked++;
    }
  }
  return [...rows].map(([wave, counts]) => {
    const clear = clears.get(wave);
    return {
      wave,
      ...counts,
      lives: clear?.lives,
      credits: clear?.credits,
      towers: clear?.towers,
    };
  });
}

/**
 * Plays a seeded game with the scripted player and returns the whole report
 * as text. Pure: the same arguments always give the same text.
 */
export function buildReport({seed, waves, speed}: Args): string {
  const bot = createBot(generateMap(seed));
  const driven = createRunner(seed, game =>
    game.wave >= waves && !game.running ? [] : bot(game)
  );
  const {game} = driven;
  const clears = new Map<number, ClearSnapshot>();
  const done = () =>
    game.over ||
    (game.wave >= waves && !game.running) ||
    game.tick >= MAX_TICKS;
  const clock = createClock();
  while (!done()) {
    const ticks = advanceClock(clock, FRAME_SECONDS, speed);
    for (let i = 0; i < ticks && !done(); i++) {
      driven.step();
      for (const event of game.events) {
        if (event.type === 'waveCleared') {
          clears.set(event.wave, {
            lives: game.lives,
            credits: game.credits,
            towers: game.towers.length,
          });
        }
      }
    }
  }
  const outcome = game.over
    ? `Core fell in wave ${game.wave}`
    : game.wave >= waves
      ? `Core held through wave ${game.wave}`
      : `Stopped at the time limit in wave ${game.wave}`;
  const seconds = (game.tick * TICK_SECONDS).toFixed(1);
  return [
    `Scrapline sim · seed ${seed} · ${waves} waves · speed ${speed}`,
    '',
    'Map (S spawn, C core, # belt, . plate)',
    formatMap(game.map),
    '',
    formatTable(summarizeWaves(driven.events, clears)),
    '',
    `Result: ${outcome} · lives ${game.lives} · credits ${game.credits} · ` +
      `towers ${game.towers.length} · ${game.tick} ticks (${seconds} s) · ` +
      `fingerprint ${fingerprint(game)}`,
  ].join('\n');
}
