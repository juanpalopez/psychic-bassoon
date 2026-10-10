import {mkdirSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {ENEMY_IDS} from '../src/content';
import {
  buildWave,
  createBot,
  createRng,
  createGame,
  deriveRng,
  enemyStatsForWave,
  fingerprint,
  generateMap,
  nextFloat,
  nextInt,
  nextRange,
  run,
} from '../src/sim';
import type {GameState} from '../src/sim';

/**
 * The oracle for the Godot port: JSON produced by the TypeScript sim that the
 * GDScript sim must reproduce exactly (see fixtures/README.md). Everything
 * here is deterministic: no clock, no randomness outside the seeded PRNG.
 */

const SEEDS = [1, 7, 42, 99, 2024, 7920, 104729, 4294967295];
const MAP_SEEDS = Array.from({length: 120}, (_, i) => i * 7919 + 1);
const WAVE_SEEDS = SEEDS;
const MAX_WAVE = 40;
const REPLAY_SEEDS = [1, 42, 2024, 7920];
const REPLAY_TICKS = 30 * 180;
const CHECKPOINT_EVERY = 600;

type Json = unknown;

function prng(): Json {
  return SEEDS.map(seed => {
    const a = createRng(seed);
    const floats = Array.from({length: 16}, () => nextFloat(a));
    const b = createRng(seed);
    const ints = Array.from({length: 16}, () => nextInt(b, 6));
    const c = createRng(seed);
    const ranges = Array.from({length: 8}, () => nextRange(c, 0.8, 3.2));
    return {
      seed,
      floats,
      ints6: ints,
      ranges,
      derived: [0, 1, 2, 100].map(stream => ({
        stream,
        state: deriveRng(seed, stream).state,
      })),
    };
  });
}

function maps(): Json {
  return MAP_SEEDS.map(seed => {
    const map = generateMap(seed);
    return {
      seed,
      path: map.path.map(c => [c.col, c.row]),
      routes: map.routes.map(r => r.map(c => [c.col, c.row])),
      // one string per row: '#' road, '.' plot
      tiles: map.tiles.map(line =>
        line.map(t => (t === 'road' ? '#' : '.')).join('')
      ),
    };
  });
}

function waves(): Json {
  return WAVE_SEEDS.map(seed => {
    const rng = deriveRng(seed, 1); // RNG_STREAMS.waves, drawn in wave order
    return {
      seed,
      waves: Array.from({length: MAX_WAVE}, (_, i) =>
        buildWave(i + 1, rng).map(o => [o.type, o.gap])
      ),
    };
  });
}

function scaling(): Json {
  return ENEMY_IDS.map(id => ({
    id,
    waves: Array.from({length: 60}, (_, i) => {
      const s = enemyStatsForWave(id, i + 1);
      return [s.hp, s.speed, s.reward, s.armor];
    }),
  }));
}

/** The values of a state that must match exactly at a checkpoint. */
function snapshot(game: GameState): Json {
  return {
    tick: game.tick,
    gold: game.gold,
    lives: game.lives,
    wave: game.wave,
    running: game.running,
    over: game.over,
    towers: game.towers.map(t => [
      t.id,
      t.type,
      t.level,
      t.col,
      t.row,
      t.invested,
      t.cooldown,
    ]),
    enemies: game.enemies.map(e => [
      e.id,
      e.type,
      e.route,
      e.hp,
      e.distance,
      e.x,
      e.y,
      e.slow,
      e.slowTimer,
    ]),
    shots: game.shots.map(s => [s.x, s.y, s.targetId, s.damage]),
    spawners: game.spawners.map(s => [s.wave, s.timer, s.queue.length]),
    rngState: game.rng.state,
    routeRngState: game.routeRng.state,
    nextId: game.nextId,
  };
}

function replays(): Json {
  return REPLAY_SEEDS.map(seed => {
    // the scripted bot plays; checkpoints are taken by re-running to each tick
    const checkpoints: Json[] = [];
    const bot = createBot(createGame(seed).map);
    const result = run(seed, REPLAY_TICKS, game => {
      if (game.tick > 0 && game.tick % CHECKPOINT_EVERY === 0) {
        checkpoints.push(snapshot(game));
      }
      return bot(game);
    });
    return {
      seed,
      ticks: result.game.tick,
      commands: result.log.map(c => [c.tick, c.command]),
      checkpoints,
      final: snapshot(result.game),
      // for reference only: the TypeScript fingerprint cannot be reproduced in
      // GDScript, the checkpoints above are the comparison
      fingerprint: fingerprint(result.game),
    };
  });
}

/** File name to JSON text. Stable key order and formatting. */
export function buildFixtures(): Record<string, string> {
  const files: Record<string, Json> = {
    'prng.json': prng(),
    'maps.json': maps(),
    'waves.json': waves(),
    'scaling.json': scaling(),
    'replays.json': replays(),
  };
  return Object.fromEntries(
    Object.entries(files).map(([name, data]) => [
      name,
      JSON.stringify(data) + '\n',
    ])
  );
}

if (process.argv[1]?.endsWith('export-fixtures.ts')) {
  const dir = process.argv[2] ?? 'fixtures';
  mkdirSync(dir, {recursive: true});
  for (const [name, text] of Object.entries(buildFixtures())) {
    writeFileSync(join(dir, name), text);
    console.log(`${name}: ${(text.length / 1024).toFixed(0)} kB`);
  }
}
