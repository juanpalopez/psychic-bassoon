import {ENEMIES, RULES, TOWERS} from '../../content';
import type {EnemyId} from '../../content';
import type {Enemy, GameState, Tower} from '../game';
import {TICK_SECONDS} from '../time';
import {distance, positionAt} from '../map';
import {nextInt} from '../rng';
import type {Point} from '../map';
import {enemyStatsForWave} from './scaling';

/** Puts a foe of `wave`'s strength on the spawn point. */
export function spawnEnemy(
  game: GameState,
  type: EnemyId,
  wave: number,
  route?: number
): Enemy {
  const base = ENEMIES[type];
  const stats = enemyStatsForWave(type, wave);
  // each foe takes one route; with several, the map's own stream picks
  const lane =
    route ??
    (game.routes.length > 1 ? nextInt(game.routeRng, game.routes.length) : 0);
  const laneRoute = game.routes[lane];
  if (!laneRoute) throw new RangeError(`no route ${lane}`);
  const start = positionAt(laneRoute, 0);
  const enemy: Enemy = {
    id: game.nextId++,
    type,
    hp: stats.hp,
    maxHp: stats.hp,
    speed: stats.speed,
    reward: stats.reward,
    armor: stats.armor,
    radius: base.radius,
    leak: base.leak,
    route: lane,
    distance: 0,
    x: start.x,
    y: start.y,
    slow: 0,
    slowTimer: 0,
    alive: true,
  };
  game.enemies.push(enemy);
  game.events.push({
    type: 'enemySpawned',
    enemyId: enemy.id,
    foe: type,
    wave,
  });
  return enemy;
}

/** Armor cuts a hit, but never below `minDamageFraction` of it. */
export function damageEnemy(
  game: GameState,
  enemy: Enemy,
  amount: number
): void {
  if (!enemy.alive) return;
  enemy.hp -= Math.max(amount * RULES.minDamageFraction, amount - enemy.armor);
  if (enemy.hp <= 0) {
    enemy.alive = false;
    game.gold += enemy.reward;
    game.events.push({
      type: 'enemyKilled',
      enemyId: enemy.id,
      foe: enemy.type,
      reward: enemy.reward,
      x: enemy.x,
      y: enemy.y,
    });
  }
}

function inRange(game: GameState, centre: Point, radius: number): Enemy[] {
  const limit = radius * radius;
  return game.enemies.filter(e => {
    const dx = e.x - centre.x;
    const dy = e.y - centre.y;
    return e.alive && dx * dx + dy * dy <= limit;
  });
}

function moveEnemies(game: GameState): void {
  for (const enemy of game.enemies) {
    if (enemy.slowTimer > 0) enemy.slowTimer -= TICK_SECONDS;
    else enemy.slow = 0;
    enemy.distance += enemy.speed * (1 - enemy.slow) * TICK_SECONDS;
    const route = game.routes[enemy.route] ?? game.route;
    if (enemy.distance >= route.total) {
      enemy.alive = false;
      game.lives -= enemy.leak;
      game.events.push({
        type: 'enemyLeaked',
        enemyId: enemy.id,
        leak: enemy.leak,
      });
      continue;
    }
    const p = positionAt(route, enemy.distance);
    enemy.x = p.x;
    enemy.y = p.y;
  }
}

function centreOf(tower: Tower): Point {
  return {
    x: tower.col + RULES.cellCentre,
    y: tower.row + RULES.cellCentre,
  };
}

/**
 * The foe closest to the Heartstone, across routes (routes differ in length,
 * so distance walked is not comparable); the first one wins a tie.
 */
function frontmost(
  game: GameState,
  enemies: readonly Enemy[]
): Enemy | undefined {
  const left = (e: Enemy): number =>
    (game.routes[e.route] ?? game.route).total - e.distance;
  let best = enemies[0];
  for (const e of enemies) if (best && left(e) < left(best)) best = e;
  return best;
}

function pulse(game: GameState, tower: Tower, targets: Enemy[]): void {
  const def = TOWERS.frostSpire;
  const slow = def.slow?.[tower.level] ?? 0;
  const centre = centreOf(tower);
  game.events.push({
    type: 'towerFired',
    towerId: tower.id,
    tower: tower.type,
    level: tower.level,
    x: centre.x,
    y: centre.y,
    path: [],
  });
  for (const e of targets) {
    e.slow = Math.max(e.slow, slow);
    e.slowTimer = RULES.frostSlowSeconds;
    damageEnemy(game, e, def.damage[tower.level] ?? 0);
  }
}

function chainLightning(game: GameState, tower: Tower, first: Enemy): void {
  const def = TOWERS.stormSpire;
  const jumps = def.chain?.[tower.level] ?? 0;
  let damage = def.damage[tower.level] ?? 0;
  let current = first;
  const hit = new Set<Enemy>([current]);
  const path: Point[] = [];
  for (let i = 0; i < jumps; i++) {
    path.push({x: current.x, y: current.y});
    damageEnemy(game, current, damage);
    damage *= RULES.arcChainFalloff;
    let next: Enemy | undefined;
    let nearest = RULES.arcChainRadius * RULES.arcChainRadius;
    for (const e of game.enemies) {
      if (!e.alive || hit.has(e)) continue;
      const dx = e.x - current.x;
      const dy = e.y - current.y;
      const d2 = dx * dx + dy * dy;
      if (d2 < nearest) {
        nearest = d2;
        next = e;
      }
    }
    if (!next) break;
    current = next;
    hit.add(current);
  }
  const centre = centreOf(tower);
  game.events.push({
    type: 'towerFired',
    towerId: tower.id,
    tower: tower.type,
    level: tower.level,
    x: centre.x,
    y: centre.y,
    path,
  });
}

function fireTowers(game: GameState): void {
  for (const tower of game.towers) {
    const def = TOWERS[tower.type];
    const level = tower.level;
    tower.cooldown -= TICK_SECONDS;
    const centre = centreOf(tower);
    const targets = inRange(game, centre, def.range[level] ?? 0);
    if (tower.type === 'frostSpire') {
      if (tower.cooldown <= 0 && targets.length > 0) {
        pulse(game, tower, targets);
        tower.cooldown = 1 / (def.rate[level] ?? 1);
      }
      continue;
    }
    const target = frontmost(game, targets);
    if (!target || tower.cooldown > 0) continue;
    tower.cooldown = 1 / (def.rate[level] ?? 1);
    if (tower.type === 'ballista' || tower.type === 'catapult') {
      game.events.push({
        type: 'towerFired',
        towerId: tower.id,
        tower: tower.type,
        level,
        x: centre.x,
        y: centre.y,
        path: [{x: target.x, y: target.y}],
      });
    }
    if (tower.type === 'ballista') {
      damageEnemy(game, target, def.damage[level] ?? 0);
    } else if (tower.type === 'catapult') {
      game.shots.push({
        x: centre.x,
        y: centre.y,
        targetId: target.id,
        targetX: target.x,
        targetY: target.y,
        damage: def.damage[level] ?? 0,
        splash: def.splash?.[level] ?? 0,
      });
    } else {
      chainLightning(game, tower, target);
    }
  }
}

function moveShots(game: GameState): void {
  const step = RULES.rocketSpeed * TICK_SECONDS;
  game.shots = game.shots.filter(shot => {
    const target = game.enemies.find(e => e.id === shot.targetId && e.alive);
    if (target) {
      shot.targetX = target.x;
      shot.targetY = target.y;
    }
    const to = {x: shot.targetX, y: shot.targetY};
    const dist = distance(shot, to);
    if (dist <= step) {
      game.events.push({
        type: 'shellLanded',
        x: to.x,
        y: to.y,
        splash: shot.splash,
      });
      for (const e of inRange(game, to, shot.splash)) {
        damageEnemy(game, e, shot.damage);
      }
      return false;
    }
    shot.x += ((to.x - shot.x) / dist) * step;
    shot.y += ((to.y - shot.y) / dist) * step;
    return true;
  });
}

/** One tick of the fight: foes walk, towers fire, shells fly. */
export function stepCombat(game: GameState): void {
  moveEnemies(game);
  fireTowers(game);
  moveShots(game);
  game.enemies = game.enemies.filter(e => e.alive);
  if (game.lives <= 0) {
    game.lives = 0;
    game.over = true;
    game.events.push({type: 'gameOver', wave: game.wave});
  }
}
