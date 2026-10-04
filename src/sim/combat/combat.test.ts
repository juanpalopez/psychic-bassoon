import {describe, expect, it} from 'vitest';
import {ENEMIES, RULES, TOWERS} from '../../content';
import type {EnemyId, TowerId} from '../../content';
import {createGame, submit, tick} from '../game';
import type {Enemy, GameState} from '../game';
import {TICK_SECONDS} from '../game';
import {positionAt} from '../map';
import {damageEnemy, spawnEnemy} from './combat';

const SEED = 42;
const DISTANCE = 12;

/** A game with one tower on a plate right next to the route. */
function setup(type: TowerId, level = 0) {
  const game = createGame(SEED);
  const onRoute = positionAt(game.route, DISTANCE);
  const cell = game.map.tiles
    .flatMap((line, row) => line.map((tile, col) => ({tile, col, row})))
    .filter(c => c.tile === 'plate')
    .map(c => ({
      ...c,
      d: (c.col + 0.5 - onRoute.x) ** 2 + (c.row + 0.5 - onRoute.y) ** 2,
    }))
    .sort((a, b) => a.d - b.d)[0];
  if (!cell) throw new Error('no plate');
  game.credits = 10_000;
  submit(game, {type: 'build', tower: type, col: cell.col, row: cell.row});
  tick(game);
  for (let i = 0; i < level; i++) {
    submit(game, {type: 'upgrade', towerId: 0});
    tick(game);
  }
  const tower = game.towers[0];
  if (!tower) throw new Error('no tower');
  tower.cooldown = 0;
  game.credits = 0;
  return {game, tower};
}

/** Spawn a still enemy at a distance along the route. */
function put(
  game: GameState,
  type: EnemyId,
  distance = DISTANCE,
  wave = 1
): Enemy {
  const enemy = spawnEnemy(game, type, wave);
  enemy.speed = 0;
  enemy.distance = distance;
  const p = positionAt(game.route, distance);
  enemy.x = p.x;
  enemy.y = p.y;
  return enemy;
}

const alive = (game: GameState) => game.enemies.filter(e => e.alive);

describe('spawnEnemy', () => {
  it('puts a scaled robot on the spawn point with a fresh id', () => {
    const game = createGame(SEED);
    const a = spawnEnemy(game, 'hauler', 10);
    const b = spawnEnemy(game, 'hauler', 10);
    expect(b.id).toBe(a.id + 1);
    expect(a).toMatchObject({
      type: 'hauler',
      hp: Math.round(42 * 3.934),
      maxHp: Math.round(42 * 3.934),
      distance: 0,
      x: game.route.points[0]?.x,
      y: game.route.points[0]?.y,
      slow: 0,
      slowTimer: 0,
      alive: true,
      radius: ENEMIES.hauler.radius,
      leak: ENEMIES.hauler.leak,
    });
    expect(game.enemies).toEqual([a, b]);
  });
});

describe('damageEnemy', () => {
  it('subtracts armor from a hit', () => {
    const game = createGame(SEED);
    const smelter = spawnEnemy(game, 'smelter', 1);
    damageEnemy(game, smelter, 10);
    expect(smelter.hp).toBe(130 - (10 - 4));
  });

  it('never cuts a hit below 25% of its damage', () => {
    const game = createGame(SEED);
    const overseer = spawnEnemy(game, 'overseer', 1);
    damageEnemy(game, overseer, 4); // armor 6 would leave nothing
    expect(overseer.hp).toBe(850 - 1);
    damageEnemy(game, overseer, 8); // 8 - 6 = 2 beats 8 * 0.25 = 2: equal
    expect(overseer.hp).toBe(850 - 1 - 2);
    damageEnemy(game, overseer, 9); // 9 - 6 = 3 beats 2.25
    expect(overseer.hp).toBe(850 - 1 - 2 - 3);
  });

  it('pays the reward once and flags the kill', () => {
    const game = createGame(SEED);
    game.credits = 0;
    const skitter = spawnEnemy(game, 'skitter', 1);
    damageEnemy(game, skitter, 1000);
    damageEnemy(game, skitter, 1000);
    expect(skitter.alive).toBe(false);
    expect(game.credits).toBe(ENEMIES.skitter.reward);
  });

  it('records the kill as an event', () => {
    const game = createGame(SEED);
    const skitter = spawnEnemy(game, 'skitter', 1);
    damageEnemy(game, skitter, 1000);
    expect(game.events).toContainEqual({
      type: 'enemyKilled',
      enemyId: skitter.id,
      reward: ENEMIES.skitter.reward,
    });
  });
});

describe('movement', () => {
  it('walks speed * tick along the route', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'hauler', 1);
    const speed = enemy.speed;
    tick(game);
    tick(game);
    expect(enemy.distance).toBeCloseTo(2 * speed * TICK_SECONDS, 12);
    const p = positionAt(game.route, enemy.distance);
    expect([enemy.x, enemy.y]).toEqual([p.x, p.y]);
  });

  it('moves a slowed robot at (1 - slow) of its speed', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'hauler', 1);
    enemy.slow = 0.5;
    enemy.slowTimer = 1;
    const speed = enemy.speed;
    tick(game);
    expect(enemy.distance).toBeCloseTo(speed * 0.5 * TICK_SECONDS, 12);
  });

  it('lets a slow wear off', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'hauler', 1);
    enemy.slow = 0.5;
    enemy.slowTimer = TICK_SECONDS * 2.5;
    for (let i = 0; i < 4; i++) tick(game);
    expect(enemy.slow).toBe(0);
    expect(enemy.slowTimer).toBeLessThanOrEqual(0);
  });

  it('costs lives when a robot reaches the Core, and removes it', () => {
    const game = createGame(SEED);
    const enemy = put(game, 'smelter', game.route.total - 0.001);
    enemy.speed = 1;
    tick(game);
    expect(game.lives).toBe(RULES.startLives - ENEMIES.smelter.leak);
    expect(game.enemies).toEqual([]);
    expect(game.events).toContainEqual({
      type: 'enemyLeaked',
      enemyId: enemy.id,
      leak: ENEMIES.smelter.leak,
    });
  });

  it('ends the game at zero lives and never goes below', () => {
    const game = createGame(SEED);
    game.lives = 3;
    const enemy = put(game, 'overseer', game.route.total - 0.001);
    enemy.speed = 1;
    tick(game);
    expect(game.lives).toBe(0);
    expect(game.over).toBe(true);
    expect(game.events).toContainEqual({type: 'gameOver', wave: game.wave});
  });
});

describe('Welder', () => {
  it('shoots the robot furthest along the route', () => {
    const {game} = setup('welder');
    const back = put(game, 'hauler', DISTANCE - 0.5);
    const front = put(game, 'hauler', DISTANCE + 0.5);
    tick(game);
    expect(front.hp).toBe(front.maxHp - TOWERS.welder.damage[0]);
    expect(back.hp).toBe(back.maxHp);
  });

  it('fires every 1/rate seconds', () => {
    const {game, tower} = setup('welder');
    const target = put(game, 'overseer');
    target.armor = 0;
    const ticks = Math.ceil(10 / TICK_SECONDS);
    let shots = 0;
    for (let i = 0; i < ticks; i++) {
      const before = target.hp;
      tick(game);
      if (target.hp < before) shots++;
    }
    // Ticks are discrete, so a 1/3 s cooldown is 10 or 11 ticks long. The
    // exact count is pinned; it can never beat the ideal rate.
    expect(shots).toBe(28);
    expect(shots).toBeLessThanOrEqual(
      Math.floor(10 * TOWERS.welder.rate[0]) + 1
    );
    expect(tower.cooldown).toBeGreaterThan(0);
  });

  it('ignores robots out of range', () => {
    const {game} = setup('welder');
    const far = put(game, 'hauler', DISTANCE + 8);
    tick(game);
    expect(far.hp).toBe(far.maxHp);
  });

  it('hits harder at higher levels', () => {
    const {game} = setup('welder', 2);
    const target = put(game, 'overseer');
    target.armor = 0;
    tick(game);
    expect(target.hp).toBe(target.maxHp - TOWERS.welder.damage[2]);
  });
});

describe('Quench Coil', () => {
  it('slows and damages every robot in range at once', () => {
    const {game} = setup('quenchCoil');
    const a = put(game, 'hauler', DISTANCE - 0.3);
    const b = put(game, 'hauler', DISTANCE + 0.3);
    tick(game);
    for (const e of [a, b]) {
      expect(e.slow).toBe(TOWERS.quenchCoil.slow?.[0]);
      expect(e.slowTimer).toBe(RULES.quenchSlowSeconds);
      expect(e.hp).toBe(e.maxHp - TOWERS.quenchCoil.damage[0]);
    }
  });

  it('keeps the stronger of two slows', () => {
    const {game} = setup('quenchCoil');
    const e = put(game, 'hauler');
    e.slow = 0.9;
    e.slowTimer = 1;
    tick(game);
    expect(e.slow).toBe(0.9);
  });

  it('does nothing with no robot in range, and fires at once when one comes', () => {
    const {game, tower} = setup('quenchCoil');
    tick(game);
    tick(game);
    const e = put(game, 'hauler');
    tick(game);
    expect(e.slow).toBe(TOWERS.quenchCoil.slow?.[0]);
    expect(tower.cooldown).toBeGreaterThan(0);
  });
});

describe('Rivet Mortar', () => {
  it('launches a shell that flies at the shell speed and then splashes', () => {
    const {game} = setup('rivetMortar');
    const target = put(game, 'overseer');
    target.armor = 0;
    const neighbour = put(game, 'overseer', DISTANCE + 0.5);
    neighbour.armor = 0;
    const far = put(game, 'overseer', DISTANCE + 4);
    far.armor = 0;
    tick(game);
    expect(game.shots).toHaveLength(1);
    expect(target.hp).toBe(target.maxHp);
    for (let i = 0; i < 60 && game.shots.length; i++) tick(game);
    expect(game.shots).toEqual([]);
    const dmg = TOWERS.rivetMortar.damage[0];
    expect(target.hp).toBe(target.maxHp - dmg);
    expect(neighbour.hp).toBe(neighbour.maxHp - dmg);
    expect(far.hp).toBe(far.maxHp);
  });

  it('flies on to the last known spot if the target dies first', () => {
    const {game} = setup('rivetMortar');
    const target = put(game, 'hauler');
    tick(game);
    expect(game.shots).toHaveLength(1);
    damageEnemy(game, target, 1e6);
    game.enemies = game.enemies.filter(e => e.alive);
    for (let i = 0; i < 60 && game.shots.length; i++) tick(game);
    expect(game.shots).toEqual([]);
  });

  it('moves a shell by exactly shell speed per second', () => {
    const {game, tower} = setup('rivetMortar');
    put(game, 'overseer');
    tick(game);
    const shot = game.shots[0];
    if (!shot) throw new Error('no shot');
    const before = {x: shot.x, y: shot.y};
    tick(game);
    const moved = Math.hypot(shot.x - before.x, shot.y - before.y);
    expect(moved).toBeCloseTo(RULES.rocketSpeed * TICK_SECONDS, 9);
    expect(tower.cooldown).toBeGreaterThan(0);
  });
});

describe('Mainline Arc', () => {
  it('chains through nearby robots with 80% damage per jump', () => {
    const {game} = setup('mainlineArc');
    const hits = [0, 0.5, 1, 1.5].map(o => {
      const e = put(game, 'overseer', DISTANCE + o);
      e.armor = 0;
      return e;
    });
    tick(game);
    const dmg = TOWERS.mainlineArc.damage[0];
    // targets the front-most robot first, then jumps to its nearest neighbour
    const chain = TOWERS.mainlineArc.chain?.[0] ?? 0;
    const front = [...hits].reverse();
    front.forEach((e, i) => {
      const expected =
        i < chain ? e.maxHp - dmg * RULES.arcChainFalloff ** i : e.maxHp;
      expect(e.hp).toBeCloseTo(expected, 9);
    });
  });

  it('never hits the same robot twice and stops when none is near', () => {
    const {game} = setup('mainlineArc');
    const lone = put(game, 'overseer');
    lone.armor = 0;
    tick(game);
    expect(lone.hp).toBe(lone.maxHp - TOWERS.mainlineArc.damage[0]);
  });

  it('does not jump further than the chain radius', () => {
    const {game} = setup('mainlineArc');
    const a = put(game, 'overseer', DISTANCE);
    const b = put(game, 'overseer', DISTANCE - (RULES.arcChainRadius + 0.5));
    a.armor = 0;
    b.armor = 0;
    // b is out of the tower's range or the radius; the first hit is a
    tick(game);
    expect(a.hp).toBeLessThan(a.maxHp);
    expect(b.hp).toBe(b.maxHp);
  });
});

describe('determinism', () => {
  it('replays a fight identically', () => {
    const run = () => {
      const {game} = setup('mainlineArc', 1);
      const enemy = spawnEnemy(game, 'hauler', 3);
      enemy.speed = 1;
      for (let i = 0; i < 600; i++) tick(game);
      return JSON.stringify(game);
    };
    expect(run()).toBe(run());
  });

  it('keeps living robots when none were killed', () => {
    const {game} = setup('welder');
    put(game, 'overseer');
    tick(game);
    expect(alive(game)).toHaveLength(1);
  });
});
