import {describe, expect, it} from 'vitest';
import {ENEMIES, ENEMY_IDS} from '../../content';
import {enemyStatsForWave} from './scaling';

describe('enemyStatsForWave', () => {
  it.each(ENEMY_IDS)('gives wave 1 a %s with its base numbers', id => {
    const base = ENEMIES[id];
    expect(enemyStatsForWave(id, 1)).toEqual({
      hp: base.hp,
      // wave 1 still gains the speed bonus: 1 + min(0.25, 1 * 0.006)
      speed: base.speed * 1.006,
      reward: base.reward,
      armor: base.armor,
    });
  });

  it('scales hp by 1 + 0.2(w-1) + 0.014(w-1)^2 and rounds', () => {
    // wave 10: 1 + 1.8 + 0.014 * 81 = 3.934
    expect(enemyStatsForWave('raider', 10).hp).toBe(Math.round(42 * 3.934));
    expect(enemyStatsForWave('warlord', 10).hp).toBe(Math.round(850 * 3.934));
  });

  it('raises speed by 0.6% a wave up to +25%', () => {
    expect(enemyStatsForWave('scamp', 10).speed).toBe(1.9 * 1.06);
    expect(enemyStatsForWave('scamp', 42).speed).toBe(1.9 * 1.25);
    expect(enemyStatsForWave('scamp', 500).speed).toBe(1.9 * 1.25);
  });

  it('raises reward by 4% a wave, rounded', () => {
    expect(enemyStatsForWave('ironclad', 11).reward).toBe(Math.round(13 * 1.4));
  });

  it('adds one armor every 12 waves', () => {
    expect(enemyStatsForWave('ironclad', 11).armor).toBe(4);
    expect(enemyStatsForWave('ironclad', 12).armor).toBe(5);
    expect(enemyStatsForWave('ironclad', 24).armor).toBe(6);
    expect(enemyStatsForWave('scamp', 12).armor).toBe(1);
  });
});
