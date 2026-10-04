import {describe, expect, it} from 'vitest';
import {RULES, WAVES} from '../../content';
import {createGame, submit, tick} from '../game';
import type {GameState} from '../game';
import {deriveRng, nextFloat} from '../rng';
import {RNG_STREAMS} from '../streams';
import {buildWave} from './waves';

const SEED = 2024;

/** The prototype's buildWave(), verbatim, fed by the wave stream's floats. */
function prototypeWave(w: number, random: () => number) {
  const q: {type: string; t: number}[] = [];
  const boss = w % 10 === 0;
  const swarm = w % 5 === 0 && !boss;
  const n = Math.round(6 + w * 1.4);
  const gap = Math.max(0.32, 0.95 - w * 0.025);
  for (let i = 0; i < n; i++) {
    const r = random();
    let type = 'walker';
    if (swarm) type = r < 0.75 ? 'scout' : 'walker';
    else {
      if (w >= 2 && r < 0.3) type = 'scout';
      if (w >= 4 && r > 0.82 - Math.min(0.2, w * 0.01)) type = 'tank';
    }
    q.push({
      type,
      t:
        gap *
        (type === 'tank' ? 1.4 : type === 'scout' ? (swarm ? 0.45 : 0.6) : 1),
    });
  }
  if (boss) q.push({type: 'boss', t: 1});
  if (boss) q.unshift({type: 'tank', t: gap * 2});
  return q;
}

const LORE = {
  walker: 'hauler',
  scout: 'skitter',
  tank: 'smelter',
  boss: 'overseer',
} as const;

describe('buildWave', () => {
  it('matches the prototype for waves 1 to 40 from the same random stream', () => {
    const rng = deriveRng(SEED, RNG_STREAMS.waves);
    const reference = deriveRng(SEED, RNG_STREAMS.waves);
    for (let w = 1; w <= 40; w++) {
      const expected = prototypeWave(w, () => nextFloat(reference)).map(o => ({
        type: LORE[o.type as keyof typeof LORE],
        gap: o.t,
      }));
      expect(buildWave(w, rng)).toEqual(expected);
    }
  });

  it('is reproducible from the seed', () => {
    const a = buildWave(7, deriveRng(1, RNG_STREAMS.waves));
    const b = buildWave(7, deriveRng(1, RNG_STREAMS.waves));
    expect(a).toEqual(b);
  });

  it('sends round(6 + 1.4w) robots, plus the escort and Overseer on boss waves', () => {
    const rng = deriveRng(SEED, RNG_STREAMS.waves);
    expect(buildWave(1, rng)).toHaveLength(7);
    expect(buildWave(2, rng)).toHaveLength(9);
    expect(buildWave(9, rng)).toHaveLength(19);
    expect(buildWave(10, rng)).toHaveLength(20 + 2);
    expect(buildWave(20, rng)).toHaveLength(34 + 2);
  });

  it('sends only Haulers in wave 1', () => {
    for (let seed = 0; seed < 50; seed++) {
      const wave = buildWave(1, deriveRng(seed, RNG_STREAMS.waves));
      expect(wave.every(o => o.type === 'hauler')).toBe(true);
    }
  });

  it('adds Skitters from wave 2 and Smelters from wave 4', () => {
    const seen = (w: number) => {
      const types = new Set<string>();
      for (let seed = 0; seed < 200; seed++) {
        for (const o of buildWave(w, deriveRng(seed, RNG_STREAMS.waves))) {
          types.add(o.type);
        }
      }
      return types;
    };
    expect(seen(2)).toEqual(new Set(['hauler', 'skitter']));
    expect(seen(3)).toEqual(new Set(['hauler', 'skitter']));
    expect(seen(4)).toEqual(new Set(['hauler', 'skitter', 'smelter']));
  });

  it('makes every 5th wave a Skitter swarm with short gaps', () => {
    const wave = buildWave(15, deriveRng(SEED, RNG_STREAMS.waves));
    const gap = Math.max(WAVES.gapMin, WAVES.gapBase - 15 * WAVES.gapPerWave);
    expect(wave.every(o => o.type === 'skitter' || o.type === 'hauler')).toBe(
      true
    );
    expect(wave.filter(o => o.type === 'skitter').length).toBeGreaterThan(
      wave.length / 2
    );
    for (const o of wave.filter(o => o.type === 'skitter')) {
      expect(o.gap).toBe(gap * WAVES.gapMultiplier.skitterSwarm);
    }
  });

  it('puts a Smelter escort first and the Overseer last on boss waves', () => {
    const wave = buildWave(10, deriveRng(SEED, RNG_STREAMS.waves));
    const gap = Math.max(WAVES.gapMin, WAVES.gapBase - 10 * WAVES.gapPerWave);
    expect(wave[0]).toEqual({
      type: 'smelter',
      gap: gap * WAVES.gapMultiplier.bossEscort,
    });
    expect(wave.at(-1)).toEqual({type: 'overseer', gap: WAVES.overseerGap});
    expect(wave.filter(o => o.type === 'overseer')).toHaveLength(1);
  });

  it('shrinks the gap with the wave but never below the floor', () => {
    const hauler = (w: number) => {
      for (let seed = 0; seed < 100; seed++) {
        const found = buildWave(w, deriveRng(seed, RNG_STREAMS.waves)).find(
          o => o.type === 'hauler'
        );
        if (found) return found.gap;
      }
      throw new Error('no hauler');
    };
    expect(hauler(1)).toBe(0.95 - 0.025);
    expect(hauler(3)).toBe(0.95 - 0.075);
    expect(hauler(100)).toBe(WAVES.gapMin);
  });
});

function drain(game: GameState) {
  // run until the current wave has finished spawning
  for (let i = 0; i < 3000 && game.spawners.length > 0; i++) tick(game);
}

describe('launching waves in a game', () => {
  it('queues the wave and spawns robots over time, in order', () => {
    const game = createGame(SEED);
    submit(game, {type: 'launchWave'});
    tick(game);
    expect(game.spawners).toHaveLength(1);
    expect(game.enemies).toHaveLength(0);
    const planned = game.spawners[0]?.queue.length;
    expect(planned).toBe(7);
    drain(game);
    expect(game.spawners).toEqual([]);
    expect(game.enemies.every(e => e.type === 'hauler')).toBe(true);
    expect(game.enemies).toHaveLength(7);
  });

  it('spawns the first robot after the first-spawn delay', () => {
    const game = createGame(SEED);
    submit(game, {type: 'launchWave'});
    let ticks = 1;
    tick(game);
    while (game.enemies.length === 0 && ticks < 100) {
      tick(game);
      ticks++;
    }
    expect(ticks / RULES.tickRate).toBeGreaterThanOrEqual(
      WAVES.firstSpawnDelay
    );
    expect(ticks / RULES.tickRate).toBeLessThan(
      WAVES.firstSpawnDelay + 2 / RULES.tickRate
    );
  });

  it('refuses a new wave while the last one is still spawning', () => {
    const game = createGame(SEED);
    submit(game, {type: 'launchWave'});
    tick(game);
    submit(game, {type: 'launchWave'});
    tick(game);
    expect(game.wave).toBe(1);
    expect(game.events).toEqual([
      {
        type: 'commandRejected',
        command: {type: 'launchWave'},
        reason: 'waveInProgress',
      },
    ]);
  });

  it('pays the early-call bonus once spawning is done but robots remain', () => {
    const game = createGame(SEED);
    submit(game, {type: 'launchWave'});
    tick(game);
    drain(game);
    const credits = game.credits;
    submit(game, {type: 'launchWave'});
    tick(game);
    const bonus = RULES.earlyCallBase + 1 * RULES.earlyCallPerWave;
    expect(game.wave).toBe(2);
    expect(game.credits).toBe(credits + bonus);
    expect(game.events).toContainEqual({
      type: 'waveLaunched',
      wave: 2,
      earlyBonus: bonus,
    });
  });

  it('pays the wave-clear bonus when every robot is gone', () => {
    const game = createGame(SEED);
    submit(game, {type: 'launchWave'});
    tick(game);
    drain(game);
    for (const e of game.enemies) e.alive = false;
    const credits = game.credits;
    tick(game);
    const bonus = RULES.waveClearBase + 1 * RULES.waveClearPerWave;
    expect(game.running).toBe(false);
    expect(game.credits).toBe(credits + bonus);
    expect(game.events).toContainEqual({
      type: 'waveCleared',
      wave: 1,
      bonus,
    });
    tick(game);
    expect(game.credits).toBe(credits + bonus);
  });

  it('gives no wave-clear bonus once the game is over', () => {
    const game = createGame(SEED);
    game.lives = 1;
    submit(game, {type: 'launchWave'});
    tick(game);
    drain(game);
    const first = game.enemies[0];
    if (!first) throw new Error('no robot');
    first.distance = game.route.total;
    for (const e of game.enemies.slice(1)) e.alive = false;
    const credits = game.credits;
    tick(game);
    expect(game.over).toBe(true);
    expect(game.credits).toBe(credits);
    expect(game.events.some(e => e.type === 'waveCleared')).toBe(false);
  });

  it('uses its own random stream, so building towers never changes a wave', () => {
    const plain = createGame(SEED);
    submit(plain, {type: 'launchWave'});
    tick(plain);
    const built = createGame(SEED);
    const cell = built.map.tiles
      .flatMap((l, row) => l.map((t, col) => ({t, col, row})))
      .find(c => c.t === 'plate');
    if (!cell) throw new Error('no plate');
    submit(built, {
      type: 'build',
      tower: 'welder',
      col: cell.col,
      row: cell.row,
    });
    submit(built, {type: 'launchWave'});
    tick(built);
    expect(built.spawners).toEqual(plain.spawners);
  });
});
