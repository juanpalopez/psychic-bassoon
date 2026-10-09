import {RULES, WAVES} from '../../content';
import type {EnemyId} from '../../content';
import {spawnEnemy} from '../combat';
import type {GameState, SpawnOrder} from '../game';
import {TICK_SECONDS} from '../time';
import {nextFloat} from '../rng';
import type {Rng} from '../rng';

/**
 * Lists the foes of wave `w` in spawn order, each with the pause before the
 * next one. Draws one float per foe from `rng`, in order.
 */
export function buildWave(w: number, rng: Rng): SpawnOrder[] {
  const boss = w % WAVES.bossEvery === 0;
  const swarm = w % WAVES.swarmEvery === 0 && !boss;
  const count = Math.round(WAVES.baseCount + w * WAVES.countPerWave);
  const gap = Math.max(WAVES.gapMin, WAVES.gapBase - w * WAVES.gapPerWave);
  const ironcladThreshold =
    WAVES.ironcladBaseThreshold -
    Math.min(WAVES.ironcladThresholdCap, w * WAVES.ironcladThresholdPerWave);
  const orders: SpawnOrder[] = [];
  for (let i = 0; i < count; i++) {
    const roll = nextFloat(rng);
    let type: EnemyId = 'raider';
    if (swarm) {
      type = roll < WAVES.swarmScampChance ? 'scamp' : 'raider';
    } else {
      if (w >= WAVES.scampFromWave && roll < WAVES.scampChance) {
        type = 'scamp';
      }
      if (w >= WAVES.ironcladFromWave && roll > ironcladThreshold) {
        type = 'ironclad';
      }
    }
    const multiplier =
      type === 'ironclad'
        ? WAVES.gapMultiplier.ironclad
        : type === 'scamp'
          ? swarm
            ? WAVES.gapMultiplier.scampSwarm
            : WAVES.gapMultiplier.scamp
          : WAVES.gapMultiplier.raider;
    orders.push({type, gap: gap * multiplier});
  }
  if (boss) {
    orders.push({type: 'warlord', gap: WAVES.warlordGap});
    orders.unshift({
      type: 'ironclad',
      gap: gap * WAVES.gapMultiplier.bossEscort,
    });
  }
  return orders;
}

/** Queues the current wave for spawning. Called by the `launchWave` command. */
export function startWave(game: GameState): void {
  game.spawners.push({
    queue: buildWave(game.wave, game.rng),
    timer: WAVES.firstSpawnDelay,
    wave: game.wave,
  });
}

/** Releases queued foes as their timers run out. */
export function stepSpawners(game: GameState): void {
  for (const spawner of game.spawners) {
    spawner.timer -= TICK_SECONDS;
    while (spawner.timer <= 0) {
      const order = spawner.queue.shift();
      if (!order) break;
      spawnEnemy(game, order.type, spawner.wave);
      spawner.timer += order.gap;
    }
  }
  game.spawners = game.spawners.filter(s => s.queue.length > 0);
}

/** Ends the wave and pays the clear bonus once nothing is left to fight. */
export function settleWave(game: GameState): void {
  if (!game.running || game.spawners.length > 0 || game.enemies.length > 0) {
    return;
  }
  game.running = false;
  const bonus = RULES.waveClearBase + game.wave * RULES.waveClearPerWave;
  game.gold += bonus;
  game.events.push({type: 'waveCleared', wave: game.wave, bonus});
}
