import {describe, expect, it} from 'vitest';
import {createGame, spawnEnemy, tick} from '../sim';
import {createInterpolator} from './interpolation';
import type {RobotPose} from './units';

function setup() {
  const game = createGame(42);
  const enemy = spawnEnemy(game, 'hauler', 1);
  const interp = createInterpolator();
  const out: RobotPose[] = [];
  return {game, enemy, interp, out};
}

describe('interpolator', () => {
  it('blends from the last tick to the current one', () => {
    const {game, enemy, interp, out} = setup();
    interp.capture(game);
    const before = {x: enemy.x, y: enemy.y};
    enemy.distance += 1;
    enemy.x += 1;
    interp.poses(game, 0, out);
    expect([out[0]?.x, out[0]?.y]).toEqual([before.x, before.y]);
    interp.poses(game, 0.5, out);
    expect(out[0]?.x).toBeCloseTo(before.x + 0.5, 9);
    interp.poses(game, 1, out);
    expect(out[0]?.x).toBeCloseTo(enemy.x, 9);
  });

  it('draws a robot that has no history where it is', () => {
    const {game, enemy, interp, out} = setup();
    interp.poses(game, 0.5, out);
    expect([out[0]?.x, out[0]?.y]).toEqual([enemy.x, enemy.y]);
  });

  it('forgets robots that are gone', () => {
    const {game, interp, out} = setup();
    interp.capture(game);
    game.enemies = [];
    interp.poses(game, 0.5, out);
    expect(out).toHaveLength(0);
  });

  it('faces the way the robot walks (0 faces +z, down the board)', () => {
    const {game, enemy, interp, out} = setup();
    interp.capture(game);
    enemy.y += 1;
    interp.poses(game, 1, out);
    expect(out[0]?.heading).toBeCloseTo(0, 9);
    interp.capture(game);
    enemy.x += 1;
    interp.poses(game, 1, out);
    expect(out[0]?.heading).toBeCloseTo(Math.PI / 2, 9);
  });

  it('keeps its heading while the robot stands still', () => {
    const {game, enemy, interp, out} = setup();
    interp.capture(game);
    enemy.x += 1;
    interp.poses(game, 1, out);
    interp.capture(game);
    interp.poses(game, 1, out);
    expect(out[0]?.heading).toBeCloseTo(Math.PI / 2, 9);
  });

  it('reuses its pose objects frame after frame', () => {
    const {game, interp, out} = setup();
    interp.capture(game);
    interp.poses(game, 0.3, out);
    const first = out[0];
    tick(game);
    interp.capture(game);
    interp.poses(game, 0.6, out);
    expect(out[0]).toBe(first);
  });
});
