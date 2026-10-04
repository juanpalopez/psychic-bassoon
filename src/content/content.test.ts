import {readFileSync} from 'node:fs';
import {describe, expect, it} from 'vitest';
import {
  ENEMIES,
  ENEMY_IDS,
  GRID,
  MAP,
  RULES,
  TOWERS,
  TOWER_IDS,
  WAVES,
} from './index';

// The prototype is the balance reference until Phase 2's gate passes, so the
// content must match its tables exactly. Read them straight from the source.
const html = readFileSync('prototype/scrapline.html', 'utf8');

function literal(name: string): Record<string, Record<string, unknown>> {
  const match = new RegExp(`const ${name}=(\\{[\\s\\S]*?\\n\\});`).exec(html);
  if (!match?.[1]) throw new Error(`prototype has no ${name} table`);
  return new Function(`return (${match[1]})`)() as Record<
    string,
    Record<string, unknown>
  >;
}

const PROTOTYPE_DEF = literal('DEF');
const PROTOTYPE_EN = literal('EN');

const TOWER_TO_PROTOTYPE = {
  welder: 'laser',
  rivetMortar: 'rocket',
  quenchCoil: 'emp',
  mainlineArc: 'tesla',
} as const;

const ENEMY_TO_PROTOTYPE = {
  skitter: 'scout',
  hauler: 'walker',
  smelter: 'tank',
  overseer: 'boss',
} as const;

describe('towers', () => {
  it('lists the four lore names in prototype order', () => {
    expect(TOWER_IDS).toEqual([
      'welder',
      'rivetMortar',
      'quenchCoil',
      'mainlineArc',
    ]);
  });

  it.each(TOWER_IDS)('%s matches the prototype numbers', id => {
    const proto = PROTOTYPE_DEF[TOWER_TO_PROTOTYPE[id]];
    const tower = TOWERS[id];
    expect(tower.cost).toEqual(proto?.cost);
    expect(tower.damage).toEqual(proto?.dmg);
    expect(tower.range).toEqual(proto?.range);
    expect(tower.rate).toEqual(proto?.rate);
    expect(tower.splash).toEqual(proto?.splash);
    expect(tower.slow).toEqual(proto?.slow);
    expect(tower.chain).toEqual(proto?.chain);
  });

  it('has exactly three levels for every stat', () => {
    for (const id of TOWER_IDS) {
      const tower = TOWERS[id];
      for (const stat of [tower.cost, tower.damage, tower.range, tower.rate]) {
        expect(stat).toHaveLength(RULES.towerLevels);
      }
    }
  });
});

describe('enemies', () => {
  it('lists the four lore names in prototype order', () => {
    expect(ENEMY_IDS).toEqual(['skitter', 'hauler', 'smelter', 'overseer']);
  });

  it.each(ENEMY_IDS)('%s matches the prototype numbers', id => {
    const proto = PROTOTYPE_EN[ENEMY_TO_PROTOTYPE[id]];
    const enemy = ENEMIES[id];
    expect(enemy.hp).toBe(proto?.hp);
    expect(enemy.speed).toBe(proto?.spd);
    expect(enemy.reward).toBe(proto?.reward);
    expect(enemy.armor).toBe(proto?.armor);
    expect(enemy.radius).toBe(proto?.r);
    expect(enemy.leak).toBe(proto?.leak);
  });
});

describe('grid and rules', () => {
  it('matches the prototype board and starting state', () => {
    expect(GRID).toEqual({cols: 9, rows: 13});
    expect(RULES.startCredits).toBe(180);
    expect(RULES.startLives).toBe(20);
    expect(RULES.sellRefund).toBe(0.7);
    expect(RULES.minDamageFraction).toBe(0.25);
  });

  it('runs on a fixed 30 Hz tick with the prototype frame clamp', () => {
    expect(RULES.tickRate).toBe(30);
    expect(RULES.maxFrameSeconds).toBe(0.05);
    expect(RULES.maxGameSpeed).toBe(3);
  });

  it('matches the prototype early-call bonus', () => {
    expect(RULES.earlyCallBase).toBe(10);
    expect(RULES.earlyCallPerWave).toBe(2);
  });

  it('matches the prototype tower mechanics', () => {
    expect(RULES.quenchSlowSeconds).toBe(1.4);
    expect(RULES.rocketSpeed).toBe(5.5);
    expect(RULES.arcChainRadius).toBe(1.6);
    expect(RULES.arcChainFalloff).toBe(0.8);
    expect(RULES.spawnOffset).toBe(0.45);
    expect(RULES.cellCentre).toBe(0.5);
  });
});

describe('map generation', () => {
  it('matches the prototype path generator', () => {
    expect(MAP).toEqual({
      minExtraCells: 16,
      maxAttempts: 300,
      minRunDown: 2,
      runDownVariance: 2,
      minTurnColumns: 3,
      startMargin: 1,
    });
  });
});

describe('wave tables', () => {
  it('matches the prototype wave shape', () => {
    expect(WAVES.bossEvery).toBe(10);
    expect(WAVES.swarmEvery).toBe(5);
    expect(WAVES.baseCount).toBe(6);
    expect(WAVES.countPerWave).toBe(1.4);
    expect(WAVES.firstSpawnDelay).toBe(0.2);
  });

  it('matches the prototype spawn gaps', () => {
    expect(WAVES.gapBase).toBe(0.95);
    expect(WAVES.gapPerWave).toBe(0.025);
    expect(WAVES.gapMin).toBe(0.32);
    expect(WAVES.gapMultiplier).toEqual({
      smelter: 1.4,
      skitter: 0.6,
      skitterSwarm: 0.45,
      hauler: 1,
      bossEscort: 2,
    });
    expect(WAVES.overseerGap).toBe(1);
  });

  it('matches the prototype enemy mix', () => {
    expect(WAVES.swarmSkitterChance).toBe(0.75);
    expect(WAVES.skitterFromWave).toBe(2);
    expect(WAVES.skitterChance).toBe(0.3);
    expect(WAVES.smelterFromWave).toBe(4);
    expect(WAVES.smelterBaseThreshold).toBe(0.82);
    expect(WAVES.smelterThresholdPerWave).toBe(0.01);
    expect(WAVES.smelterThresholdCap).toBe(0.2);
  });

  it('matches the prototype per-wave scaling', () => {
    expect(WAVES.hpLinear).toBe(0.2);
    expect(WAVES.hpQuadratic).toBe(0.014);
    expect(WAVES.speedPerWave).toBe(0.006);
    expect(WAVES.speedCap).toBe(0.25);
    expect(WAVES.rewardPerWave).toBe(0.04);
    expect(WAVES.armorEveryWaves).toBe(12);
  });
});
