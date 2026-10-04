import {describe, expect, it} from 'vitest';
import {PALETTE} from '../palette';
import {effectsFromEvent, sparkCount, stepEffects} from './model';
import type {Effect} from './model';

const fixed = () => 0.5;

describe('sparkCount', () => {
  it('sends 10 sparks for a robot and 26 for the Overseer', () => {
    expect(sparkCount('hauler', false)).toBe(10);
    expect(sparkCount('overseer', false)).toBe(26);
  });

  it('cuts sparks to a quarter or less under reduced motion', () => {
    expect(sparkCount('hauler', true)).toBeLessThanOrEqual(3);
    expect(sparkCount('overseer', true)).toBeLessThanOrEqual(7);
    expect(sparkCount('hauler', true)).toBeGreaterThan(0);
  });
});

describe('effectsFromEvent', () => {
  it('turns a Welder shot into a short beam in the Welder colour', () => {
    const [beam, ...rest] = effectsFromEvent(
      {
        type: 'towerFired',
        towerId: 1,
        tower: 'welder',
        level: 0,
        x: 1.5,
        y: 2.5,
        path: [{x: 4, y: 5}],
      },
      false,
      fixed
    );
    expect(rest).toEqual([]);
    expect(beam).toMatchObject({
      kind: 'beam',
      from: {x: 1.5, y: 2.5},
      to: {x: 4, y: 5},
      color: PALETTE.towers.welder,
      life: 0.09,
    });
  });

  it('turns a Mainline Arc into one polyline through every target', () => {
    const [arc] = effectsFromEvent(
      {
        type: 'towerFired',
        towerId: 1,
        tower: 'mainlineArc',
        level: 1,
        x: 0,
        y: 0,
        path: [
          {x: 1, y: 1},
          {x: 2, y: 1},
        ],
      },
      false,
      fixed
    );
    expect(arc).toMatchObject({kind: 'arc', color: PALETTE.towers.mainlineArc});
    expect((arc as Extract<Effect, {kind: 'arc'}>).points).toEqual([
      {x: 0, y: 0},
      {x: 1, y: 1},
      {x: 2, y: 1},
    ]);
  });

  it('turns a Quench Coil pulse into a ring as wide as its range', () => {
    const [ring] = effectsFromEvent(
      {
        type: 'towerFired',
        towerId: 1,
        tower: 'quenchCoil',
        level: 1,
        x: 3,
        y: 3,
        path: [],
      },
      false,
      fixed
    );
    expect(ring).toMatchObject({kind: 'ring', x: 3, y: 3, radius: 2.0});
  });

  it('draws no effect for a mortar launch, the shell is drawn from state', () => {
    expect(
      effectsFromEvent(
        {
          type: 'towerFired',
          towerId: 1,
          tower: 'rivetMortar',
          level: 0,
          x: 0,
          y: 0,
          path: [{x: 1, y: 1}],
        },
        false,
        fixed
      )
    ).toEqual([]);
  });

  it('turns a landed shell into a blast of its splash radius', () => {
    expect(
      effectsFromEvent(
        {type: 'shellLanded', x: 2, y: 3, splash: 0.95},
        false,
        fixed
      )
    ).toEqual([
      expect.objectContaining({kind: 'boom', x: 2, y: 3, radius: 0.95}),
    ]);
  });

  it('turns a kill into sparks at the robot, fewer under reduced motion', () => {
    const event = {
      type: 'enemyKilled',
      enemyId: 1,
      robot: 'hauler',
      reward: 6,
      x: 4,
      y: 5,
    } as const;
    const full = effectsFromEvent(event, false, fixed);
    const calm = effectsFromEvent(event, true, fixed);
    expect(full).toHaveLength(10);
    expect(full.every(e => e.kind === 'spark' && e.x === 4 && e.y === 5)).toBe(
      true
    );
    expect(calm.length).toBeLessThan(full.length);
  });

  it('ignores events with nothing to show', () => {
    expect(
      effectsFromEvent({type: 'towerBuilt', towerId: 1}, false, fixed)
    ).toEqual([]);
  });
});

describe('stepEffects', () => {
  it('ages effects and removes the ones that ran out', () => {
    const list: Effect[] = [
      {kind: 'ring', x: 0, y: 0, radius: 1, color: 1, life: 0.1, max: 0.45},
      {kind: 'ring', x: 0, y: 0, radius: 1, color: 1, life: 0.5, max: 0.45},
    ];
    stepEffects(list, 0.2);
    expect(list).toHaveLength(1);
    expect(list[0]?.life).toBeCloseTo(0.3, 9);
  });

  it('moves sparks and slows them', () => {
    const list: Effect[] = [
      {kind: 'spark', x: 0, y: 0, vx: 2, vy: -1, life: 0.5, max: 0.5},
    ];
    stepEffects(list, 0.1);
    const spark = list[0];
    if (spark?.kind !== 'spark') throw new Error('spark gone');
    expect(spark.x).toBeCloseTo(0.2, 9);
    expect(spark.y).toBeCloseTo(-0.1, 9);
    expect(spark.vx).toBeLessThan(2);
  });
});
