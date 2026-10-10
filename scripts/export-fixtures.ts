import {mkdirSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {ENEMY_IDS, TOWER_IDS, TOWERS} from '../src/content';
import {
  buildWave,
  createBot,
  createGame,
  createRng,
  damageEnemy,
  deriveRng,
  enemyStatsForWave,
  fingerprint,
  generateMap,
  nextFloat,
  nextInt,
  nextRange,
  run,
  spawnEnemy,
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

function bitsOf(value: number): string {
  const view = new DataView(new ArrayBuffer(8));
  view.setFloat64(0, value);
  return view.getBigUint64(0).toString(16).padStart(16, '0');
}

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
      // the same 16 floats as 16 hex digits of their IEEE-754 bits: Godot's
      // JSON parser is not guaranteed to round correctly, so Phase 4 checks
      // that parsing the decimal text gives exactly these bits
      floatBits: floats.map(bitsOf),
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

/** hp lost by a foe of a wave that takes one hit of each tower and level. */
function damage(): Json {
  const hits = TOWER_IDS.flatMap(tower =>
    TOWERS[tower].damage.map((amount, level) => ({tower, level, amount}))
  );
  const lost = (
    foe: (typeof ENEMY_IDS)[number],
    wave: number,
    amount: number
  ) => {
    const game = createGame(1);
    const e = spawnEnemy(game, foe, wave, 0);
    damageEnemy(game, e, amount);
    return {
      hp: e.maxHp - e.hp,
      armor: e.armor,
      alive: e.alive,
      reward: e.reward,
    };
  };
  return {
    // every tower level against every foe at three waves
    towerHits: hits.flatMap(h =>
      ENEMY_IDS.flatMap(foe =>
        [1, 12, 24].map(wave => ({
          tower: h.tower,
          level: h.level,
          foe,
          wave,
          amount: h.amount,
          ...lost(foe, wave, h.amount),
        }))
      )
    ),
    // both sides of the armor floor (a hit never falls below 25% of its damage)
    armorFloor: [0, 3, 4, 5, 6, 7, 11].flatMap(armor =>
      [1, 3, 4, 5, 8, 9, 12, 50].map(amount => {
        const game = createGame(1);
        const e = spawnEnemy(game, 'warlord', 1, 0);
        e.armor = armor;
        const before = e.hp;
        damageEnemy(game, e, amount);
        return {armor, amount, lost: before - e.hp};
      })
    ),
    // a kill pays the reward once and a dead foe takes no more damage
    kill: (() => {
      const game = createGame(1);
      const e = spawnEnemy(game, 'scamp', 1, 0);
      const gold = game.gold;
      damageEnemy(game, e, 1000);
      damageEnemy(game, e, 1000);
      return {goldGained: game.gold - gold, alive: e.alive};
    })(),
  };
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
    spawners: game.spawners.map(s => [
      s.wave,
      s.timer,
      s.queue.map(o => [o.type, o.gap]),
    ]),
    rngState: game.rng.state,
    routeRngState: game.routeRng.state,
    nextId: game.nextId,
  };
}

function replays(): Json {
  return REPLAY_SEEDS.map(seed => {
    // The scripted bot plays. A checkpoint is the state at the START of tick N:
    // before the commands logged at tick N are submitted and before tick N runs.
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
    'damage.json': damage(),
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
