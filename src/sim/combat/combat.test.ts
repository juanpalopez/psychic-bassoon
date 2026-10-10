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

/** A game with one tower on a plot right next to the route. */
function setup(type: TowerId, level = 0) {
  const game = createGame(SEED);
  const onRoute = positionAt(game.route, DISTANCE);
  const cell = game.map.tiles
    .flatMap((line, row) => line.map((tile, col) => ({tile, col, row})))
    .filter(c => c.tile === 'plot')
    .map(c => ({
      ...c,
      d: (c.col + 0.5 - onRoute.x) ** 2 + (c.row + 0.5 - onRoute.y) ** 2,
    }))
    .sort((a, b) => a.d - b.d)[0];
  if (!cell) throw new Error('no plot');
  game.gold = 10_000;
  submit(game, {type: 'build', tower: type, col: cell.col, row: cell.row});
  tick(game);
  for (let i = 0; i < level; i++) {
    submit(game, {type: 'upgrade', towerId: 0});
    tick(game);
  }
  const tower = game.towers[0];
  if (!tower) throw new Error('no tower');
  tower.cooldown = 0;
  game.gold = 0;
  return {game, tower};
}

/** Spawn a still enemy at a distance along the route. */
function put(
  game: GameState,
  type: EnemyId,
  distance = DISTANCE,
  wave = 1
): Enemy {
  const enemy = spawnEnemy(game, type, wave, 0);
  enemy.speed = 0;
  enemy.distance = distance;
  const p = positionAt(game.route, distance);
  enemy.x = p.x;
  enemy.y = p.y;
  return enemy;
}

const alive = (game: GameState) => game.enemies.filter(e => e.alive);

describe('spawnEnemy', () => {
  it('puts a scaled foe on the spawn point with a fresh id', () => {
    const game = createGame(SEED);
    const a = spawnEnemy(game, 'raider', 10);
    const b = spawnEnemy(game, 'raider', 10);
    expect(b.id).toBe(a.id + 1);
    expect(a).toMatchObject({
      type: 'raider',
      hp: Math.round(42 * 3.934),
      maxHp: Math.round(42 * 3.934),
      distance: 0,
      x: game.route.points[0]?.x,
      y: game.route.points[0]?.y,
      slow: 0,
      slowTimer: 0,
      alive: true,
      radius: ENEMIES.raider.radius,
      leak: ENEMIES.raider.leak,
    });
    expect(game.enemies).toEqual([a, b]);
    expect(game.events).toEqual([
      {type: 'enemySpawned', enemyId: a.id, foe: 'raider', wave: 10},
      {type: 'enemySpawned', enemyId: b.id, foe: 'raider', wave: 10},
    ]);
  });
});

describe('damageEnemy', () => {
  it('subtracts armor from a hit', () => {
    const game = createGame(SEED);
    const ironclad = spawnEnemy(game, 'ironclad', 1);
    damageEnemy(game, ironclad, 10);
    expect(ironclad.hp).toBe(130 - (10 - 4));
  });

  it('never cuts a hit below 25% of its damage', () => {
    const game = createGame(SEED);
    const warlord = spawnEnemy(game, 'warlord', 1);
    damageEnemy(game, warlord, 4); // armor 6 would leave nothing
    expect(warlord.hp).toBe(850 - 1);
    damageEnemy(game, warlord, 8); // 8 - 6 = 2 beats 8 * 0.25 = 2: equal
    expect(warlord.hp).toBe(850 - 1 - 2);
    damageEnemy(game, warlord, 9); // 9 - 6 = 3 beats 2.25
    expect(warlord.hp).toBe(850 - 1 - 2 - 3);
  });

  it('pays the reward once and flags the kill', () => {
    const game = createGame(SEED);
    game.gold = 0;
    const scamp = spawnEnemy(game, 'scamp', 1);
    damageEnemy(game, scamp, 1000);
    damageEnemy(game, scamp, 1000);
    expect(scamp.alive).toBe(false);
    expect(game.gold).toBe(ENEMIES.scamp.reward);
  });

  it('records the kill as an event', () => {
    const game = createGame(SEED);
    const scamp = spawnEnemy(game, 'scamp', 1);
    damageEnemy(game, scamp, 1000);
    expect(game.events).toContainEqual({
      type: 'enemyKilled',
      enemyId: scamp.id,
      foe: 'scamp',
      reward: ENEMIES.scamp.reward,
      x: scamp.x,
      y: scamp.y,
    });
  });
});

describe('movement', () => {
  it('walks speed * tick along the route', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'raider', 1);
    const speed = enemy.speed;
    tick(game);
    tick(game);
    expect(enemy.distance).toBeCloseTo(2 * speed * TICK_SECONDS, 12);
    const p = positionAt(game.route, enemy.distance);
    expect([enemy.x, enemy.y]).toEqual([p.x, p.y]);
  });

  it('moves a slowed foe at (1 - slow) of its speed', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'raider', 1);
    enemy.slow = 0.5;
    enemy.slowTimer = 1;
    const speed = enemy.speed;
    tick(game);
    expect(enemy.distance).toBeCloseTo(speed * 0.5 * TICK_SECONDS, 12);
  });

  it('lets a slow wear off', () => {
    const game = createGame(SEED);
    const enemy = spawnEnemy(game, 'raider', 1);
    enemy.slow = 0.5;
    enemy.slowTimer = TICK_SECONDS * 2.5;
    for (let i = 0; i < 4; i++) tick(game);
    expect(enemy.slow).toBe(0);
    expect(enemy.slowTimer).toBeLessThanOrEqual(0);
  });

  it('costs lives when a foe reaches the Heartstone, and removes it', () => {
    const game = createGame(SEED);
    const enemy = put(game, 'ironclad', game.route.total - 0.001);
    enemy.speed = 1;
    tick(game);
    expect(game.lives).toBe(RULES.startLives - ENEMIES.ironclad.leak);
    expect(game.enemies).toEqual([]);
    expect(game.events).toContainEqual({
      type: 'enemyLeaked',
      enemyId: enemy.id,
      leak: ENEMIES.ironclad.leak,
    });
  });

  it('ends the game at zero lives and never goes below', () => {
    const game = createGame(SEED);
    game.lives = 3;
    const enemy = put(game, 'warlord', game.route.total - 0.001);
    enemy.speed = 1;
    tick(game);
    expect(game.lives).toBe(0);
    expect(game.over).toBe(true);
    expect(game.events).toContainEqual({type: 'gameOver', wave: game.wave});
  });
});

describe('Ballista', () => {
  it('shoots the foe furthest along the route', () => {
    const {game} = setup('ballista');
    const back = put(game, 'raider', DISTANCE - 0.5);
    const front = put(game, 'raider', DISTANCE + 0.5);
    tick(game);
    expect(front.hp).toBe(front.maxHp - TOWERS.ballista.damage[0]);
    expect(back.hp).toBe(back.maxHp);
  });

  it('fires every 1/rate seconds', () => {
    const {game, tower} = setup('ballista');
    const target = put(game, 'warlord');
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
      Math.floor(10 * TOWERS.ballista.rate[0]) + 1
    );
    expect(tower.cooldown).toBeGreaterThan(0);
  });

  it('ignores foes out of range', () => {
    const {game} = setup('ballista');
    const far = put(game, 'raider', DISTANCE + 8);
    tick(game);
    expect(far.hp).toBe(far.maxHp);
  });

  it('hits harder at higher levels', () => {
    const {game} = setup('ballista', 2);
    const target = put(game, 'warlord');
    target.armor = 0;
    tick(game);
    expect(target.hp).toBe(target.maxHp - TOWERS.ballista.damage[2]);
  });
});

describe('Frost Spire', () => {
  it('slows and damages every foe in range at once', () => {
    const {game} = setup('frostSpire');
    const a = put(game, 'raider', DISTANCE - 0.3);
    const b = put(game, 'raider', DISTANCE + 0.3);
    tick(game);
    for (const e of [a, b]) {
      expect(e.slow).toBe(TOWERS.frostSpire.slow?.[0]);
      expect(e.slowTimer).toBe(RULES.frostSlowSeconds);
      expect(e.hp).toBe(e.maxHp - TOWERS.frostSpire.damage[0]);
    }
  });

  it('keeps the stronger of two slows', () => {
    const {game} = setup('frostSpire');
    const e = put(game, 'raider');
    e.slow = 0.9;
    e.slowTimer = 1;
    tick(game);
    expect(e.slow).toBe(0.9);
  });

  it('does nothing with no foe in range, and fires at once when one comes', () => {
    const {game, tower} = setup('frostSpire');
    tick(game);
    tick(game);
    const e = put(game, 'raider');
    tick(game);
    expect(e.slow).toBe(TOWERS.frostSpire.slow?.[0]);
    expect(tower.cooldown).toBeGreaterThan(0);
  });
});

describe('Catapult', () => {
  it('launches a shell that flies at the shell speed and then splashes', () => {
    const {game} = setup('catapult');
    const target = put(game, 'warlord');
    target.armor = 0;
    const neighbour = put(game, 'warlord', DISTANCE + 0.5);
    neighbour.armor = 0;
    const far = put(game, 'warlord', DISTANCE + 4);
    far.armor = 0;
    tick(game);
    expect(game.shots).toHaveLength(1);
    expect(target.hp).toBe(target.maxHp);
    for (let i = 0; i < 60 && game.shots.length; i++) tick(game);
    expect(game.shots).toEqual([]);
    const dmg = TOWERS.catapult.damage[0];
    expect(target.hp).toBe(target.maxHp - dmg);
    expect(neighbour.hp).toBe(neighbour.maxHp - dmg);
    expect(far.hp).toBe(far.maxHp);
  });

  it('flies on to the last known spot if the target dies first', () => {
    const {game} = setup('catapult');
    const target = put(game, 'raider');
    tick(game);
    expect(game.shots).toHaveLength(1);
    damageEnemy(game, target, 1e6);
    game.enemies = game.enemies.filter(e => e.alive);
    for (let i = 0; i < 60 && game.shots.length; i++) tick(game);
    expect(game.shots).toEqual([]);
  });

  it('moves a shell by exactly shell speed per second', () => {
    const {game, tower} = setup('catapult');
    put(game, 'warlord');
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

describe('Storm Spire', () => {
  it('chains through nearby foes with 80% damage per jump', () => {
    const {game} = setup('stormSpire');
    const hits = [0, 0.5, 1, 1.5].map(o => {
      const e = put(game, 'warlord', DISTANCE + o);
      e.armor = 0;
      return e;
    });
    tick(game);
    const dmg = TOWERS.stormSpire.damage[0];
    // targets the front-most foe first, then jumps to its nearest neighbour
    const chain = TOWERS.stormSpire.chain?.[0] ?? 0;
    const front = [...hits].reverse();
    front.forEach((e, i) => {
      const expected =
        i < chain ? e.maxHp - dmg * RULES.arcChainFalloff ** i : e.maxHp;
      expect(e.hp).toBeCloseTo(expected, 9);
    });
  });

  it('never hits the same foe twice and stops when none is near', () => {
    const {game} = setup('stormSpire');
    const lone = put(game, 'warlord');
    lone.armor = 0;
    tick(game);
    expect(lone.hp).toBe(lone.maxHp - TOWERS.stormSpire.damage[0]);
  });

  it('does not jump further than the chain radius', () => {
    const {game} = setup('stormSpire');
    const a = put(game, 'warlord', DISTANCE);
    const b = put(game, 'warlord', DISTANCE - (RULES.arcChainRadius + 0.5));
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
      const {game} = setup('stormSpire', 1);
      const enemy = spawnEnemy(game, 'raider', 3);
      enemy.speed = 1;
      for (let i = 0; i < 600; i++) tick(game);
      return JSON.stringify(game);
    };
    expect(run()).toBe(run());
  });

  it('keeps living foes when none were killed', () => {
    const {game} = setup('ballista');
    put(game, 'warlord');
    tick(game);
    expect(alive(game)).toHaveLength(1);
  });
});

describe('range boundary', () => {
  it('hits a foe exactly at range, as the prototype does (<=)', () => {
    const game = createGame(SEED);
    const spots = game.map.tiles.flatMap((line, row) =>
      line.flatMap((tile, col) =>
        tile === 'plot'
          ? game.map.path.flatMap((p, i) =>
              Math.abs(p.col - col) + Math.abs(p.row - row) === 2 &&
              (p.col === col || p.row === row)
                ? [{col, row, index: i}]
                : []
            )
          : []
      )
    );
    const spot = spots[0];
    if (!spot) throw new Error('no plot exactly 2 cells from the path');
    game.gold = 10_000;
    submit(game, {
      type: 'build',
      tower: 'frostSpire',
      col: spot.col,
      row: spot.row,
    });
    tick(game);
    submit(game, {type: 'upgrade', towerId: 0}); // level 2 range is exactly 2.0
    tick(game);
    const enemy = spawnEnemy(game, 'raider', 1);
    enemy.speed = 0;
    // the route has one extra point at the front, so path cell i is point i + 1
    enemy.distance = game.route.cumulative[spot.index + 1] ?? 0;
    const tower = game.towers[0];
    if (tower) tower.cooldown = 0;
    tick(game);
    expect(enemy.slow).toBe(TOWERS.frostSpire.slow?.[1]);
  });
});

describe('events for effects', () => {
  const fired = (game: GameState) =>
    game.events.filter(e => e.type === 'towerFired');

  it('reports a Ballista beam from the tower to its target', () => {
    const {game, tower} = setup('ballista');
    const target = put(game, 'raider');
    tick(game);
    expect(fired(game)).toEqual([
      {
        type: 'towerFired',
        towerId: tower.id,
        tower: 'ballista',
        level: 0,
        x: tower.col + 0.5,
        y: tower.row + 0.5,
        path: [{x: target.x, y: target.y}],
      },
    ]);
  });

  it('reports a Frost Spire pulse with no path', () => {
    const {game} = setup('frostSpire');
    put(game, 'raider');
    tick(game);
    expect(fired(game)).toHaveLength(1);
    expect(fired(game)[0]).toMatchObject({tower: 'frostSpire', path: []});
  });

  it('reports every jump of a Storm Spire in order', () => {
    const {game} = setup('stormSpire');
    const a = put(game, 'warlord', DISTANCE + 1);
    const b = put(game, 'warlord', DISTANCE + 0.5);
    tick(game);
    const event = fired(game)[0];
    if (event?.type !== 'towerFired') throw new Error('no arc event');
    expect(event.path[0]).toEqual({x: a.x, y: a.y});
    expect(event.path[1]).toEqual({x: b.x, y: b.y});
  });

  it('reports a Catapult launch and where the shell lands', () => {
    const {game} = setup('catapult');
    const target = put(game, 'warlord');
    tick(game);
    expect(fired(game)).toHaveLength(1);
    let landed;
    for (let i = 0; i < 60 && !landed; i++) {
      tick(game);
      landed = game.events.find(e => e.type === 'shellLanded');
    }
    expect(landed).toEqual({
      type: 'shellLanded',
      x: target.x,
      y: target.y,
      splash: TOWERS.catapult.splash?.[0],
    });
  });

  it('says where and what a foe was when it died', () => {
    const game = createGame(SEED);
    const boss = spawnEnemy(game, 'warlord', 1);
    damageEnemy(game, boss, 1e6);
    expect(game.events).toContainEqual(
      expect.objectContaining({
        type: 'enemyKilled',
        foe: 'warlord',
        x: boss.x,
        y: boss.y,
      })
    );
  });
});

describe('more than one route', () => {
  const twoRoutes = () => {
    for (let seed = 1; seed < 200; seed++) {
      const game = createGame(seed);
      if (game.routes.length === 2) return game;
    }
    throw new Error('no map with a detour');
  };

  it('sends foes down both routes, each from the same spawn point', () => {
    const game = twoRoutes();
    const lanes = new Set<number>();
    for (let i = 0; i < 40; i++) lanes.add(spawnEnemy(game, 'raider', 1).route);
    expect(lanes).toEqual(new Set([0, 1]));
    const start = positionAt(game.routes[0] ?? game.route, 0);
    for (const e of game.enemies)
      expect([e.x, e.y]).toEqual([start.x, start.y]);
  });

  it('is reproducible: the same seed picks the same routes', () => {
    const pick = () => {
      const game = twoRoutes();
      return Array.from(
        {length: 20},
        () => spawnEnemy(game, 'raider', 1).route
      );
    };
    expect(pick()).toEqual(pick());
  });

  it('walks each foe along its own route, not the main one', () => {
    const game = twoRoutes();
    const main = game.routes[0] ?? game.route;
    const alt = game.routes[1] ?? game.route;
    const foe = spawnEnemy(game, 'raider', 1, 1);
    foe.speed = 0;
    // past the end of the main route, but still on the longer detour
    foe.distance = (main.total + alt.total) / 2;
    tick(game);
    expect(game.lives).toBe(RULES.startLives);
    const at = positionAt(alt, foe.distance);
    expect([foe.x, foe.y]).toEqual([at.x, at.y]);
    foe.speed = 1;
    foe.distance = alt.total - 0.001;
    tick(game);
    expect(game.lives).toBe(RULES.startLives - ENEMIES.raider.leak);
  });

  it('shoots the foe with the least distance left, not the one that walked furthest', () => {
    const game = twoRoutes();
    const main = game.routes[0] ?? game.route;
    const alt = game.routes[1] ?? game.route;
    const first = game.map.path[0];
    const second = game.map.path[1];
    if (!first || !second) throw new Error('short path');
    // a Ballista on a plot beside the shared first cells
    const plot = game.map.tiles
      .flatMap((line, row) => line.map((tile, col) => ({tile, col, row})))
      .filter(c => c.tile === 'plot')
      .sort(
        (a, b) =>
          Math.abs(a.col - first.col) +
          Math.abs(a.row - first.row) -
          (Math.abs(b.col - first.col) + Math.abs(b.row - first.row))
      )[0];
    if (!plot) throw new Error('no plot');
    game.gold = 1000;
    submit(game, {
      type: 'build',
      tower: 'ballista',
      col: plot.col,
      row: plot.row,
    });
    tick(game);
    const onMain = spawnEnemy(game, 'ironclad', 1, 0);
    const onAlt = spawnEnemy(game, 'ironclad', 1, 1);
    for (const e of [onMain, onAlt]) {
      e.speed = 0;
      e.armor = 0;
    }
    // both stand on the shared start; the detour foe has walked further, but
    // its route is longer, so it has more road left
    onMain.distance = main.cumulative[1] ?? 0;
    onAlt.distance = alt.cumulative[2] ?? 0;
    const tower = game.towers[0];
    if (tower) tower.cooldown = 0;
    const leftMain = main.total - onMain.distance;
    const leftAlt = alt.total - onAlt.distance;
    expect(leftMain).toBeLessThan(leftAlt);
    expect(onAlt.distance).toBeGreaterThan(onMain.distance);
    tick(game);
    expect(onMain.hp).toBeLessThan(onMain.maxHp);
    expect(onAlt.hp).toBe(onAlt.maxHp);
  });

  it('refuses a route index the map does not have', () => {
    const game = twoRoutes();
    expect(() => spawnEnemy(game, 'raider', 1, 5)).toThrow(RangeError);
  });
});
