import {ENEMIES, WAVES} from '../../content';
import type {EnemyId} from '../../content';

export interface ScaledStats {
  readonly hp: number;
  readonly speed: number;
  readonly reward: number;
  readonly armor: number;
}

/** Stats of a robot spawned in wave `wave`: the base numbers, scaled up. */
export function enemyStatsForWave(id: EnemyId, wave: number): ScaledStats {
  const base = ENEMIES[id];
  const n = wave - 1;
  const hpScale = 1 + WAVES.hpLinear * n + WAVES.hpQuadratic * n * n;
  return {
    hp: Math.round(base.hp * hpScale),
    speed:
      base.speed * (1 + Math.min(WAVES.speedCap, wave * WAVES.speedPerWave)),
    reward: Math.round(base.reward * (1 + WAVES.rewardPerWave * n)),
    armor: base.armor + Math.floor(wave / WAVES.armorEveryWaves),
  };
}
