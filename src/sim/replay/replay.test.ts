import {describe, expect, it} from 'vitest';
import {RULES} from '../../content';
import {createGame, submit, tick} from '../game';
import type {GameState} from '../game';
import {playBot} from './bot';
import {fingerprint, run as play, runReplay} from './replay';

const TICKS = 30 * 60 * 12; // twelve minutes of game time
const SEED = 42;

describe('headless run', () => {
  const run = playBot(SEED, TICKS);

  it('plays far enough to exercise towers, waves, kills and leaks', () => {
    const kinds = new Set(run.events.map(e => e.event.type));
    for (const kind of [
      'towerBuilt',
      'towerUpgraded',
      'waveLaunched',
      'waveCleared',
      'enemyKilled',
    ]) {
      expect(kinds.has(kind as never)).toBe(true);
    }
    expect(run.game.wave).toBeGreaterThanOrEqual(5);
    expect(run.log.length).toBeGreaterThan(10);
  });

  it('replays exactly from its seed and recorded commands', () => {
    const replay = runReplay(SEED, run.log, TICKS);
    expect(JSON.stringify(replay.game)).toBe(JSON.stringify(run.game));
    expect(replay.events).toEqual(run.events);
  });

  it('plays the same run twice from the same seed', () => {
    const again = playBot(SEED, TICKS);
    expect(again.log).toEqual(run.log);
    expect(fingerprint(again.game)).toBe(fingerprint(run.game));
  });

  it('ends in the pinned final state', () => {
    // Pinned on purpose: any change to the sim's rules or numbers changes
    // this value. Update it deliberately, in the PR that changes the rules.
    expect(fingerprint(run.game)).toMatchInlineSnapshot(`"c5812ec8"`);
  });

  it('survives a JSON save and load in the middle of the run', () => {
    const half = Math.floor(TICKS / 2);
    const first = runReplay(SEED, run.log, half);
    const restored = JSON.parse(JSON.stringify(first.game)) as GameState;
    const rest = run.log.filter(c => c.tick >= half);
    for (let i = half; i < TICKS && !restored.over; i++) {
      for (const c of rest) if (c.tick === i) submit(restored, c.command);
      tick(restored);
    }
    expect(fingerprint(restored)).toBe(fingerprint(run.game));
  });

  it('changes when a command changes', () => {
    const fewer = run.log.slice(1);
    expect(fingerprint(runReplay(SEED, fewer, TICKS).game)).not.toBe(
      fingerprint(run.game)
    );
  });
});

describe('seeds', () => {
  it('give different runs', () => {
    const prints = [1, 2, 3, 4, 5].map(seed =>
      fingerprint(playBot(seed, 30 * 60 * 3).game)
    );
    expect(new Set(prints).size).toBe(prints.length);
  });

  it.each([1, 7, 99, 2024])('replay exactly for seed %i', seed => {
    const run = playBot(seed, 30 * 60 * 6);
    const replay = runReplay(seed, run.log, 30 * 60 * 6);
    expect(fingerprint(replay.game)).toBe(fingerprint(run.game));
    expect(replay.events).toEqual(run.events);
  });
});

describe('runReplay', () => {
  it('stops at game over', () => {
    // no towers at all: the robots leak until the Core falls
    const limit = 30 * 60 * 60;
    const result = play(SEED, limit, game =>
      game.running ? [] : [{type: 'launchWave'}]
    );
    expect(result.game.over).toBe(true);
    expect(result.game.lives).toBe(0);
    expect(result.game.tick).toBeLessThan(limit);
    expect(result.events.at(-1)?.event.type).toBe('gameOver');
  });

  it('ignores commands scheduled after the run ends', () => {
    const game = runReplay(
      SEED,
      [{tick: 999_999, command: {type: 'launchWave'}}],
      10
    ).game;
    expect(game.tick).toBe(10);
    expect(game.wave).toBe(0);
  });

  it('runs on the fixed tick, with no real time involved', () => {
    const game = createGame(SEED);
    tick(game);
    expect(game.tick).toBe(1);
    expect(RULES.tickRate).toBe(30);
  });
});
