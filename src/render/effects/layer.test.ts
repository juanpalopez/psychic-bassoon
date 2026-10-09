import {describe, expect, it} from 'vitest';
import {createEffectsLayer} from './layer';

const kill = {
  type: 'enemyKilled',
  enemyId: 1,
  foe: 'warlord',
  reward: 110,
  x: 2,
  y: 3,
} as const;

const ballista = {
  type: 'towerFired',
  towerId: 1,
  tower: 'ballista',
  level: 0,
  x: 1,
  y: 1,
  path: [{x: 3, y: 3}],
} as const;

describe('effects layer', () => {
  it('draws a kill as sparks and lets them die out', () => {
    const layer = createEffectsLayer(
      () => false,
      () => 0.5
    );
    layer.spawn(kill);
    layer.update(0.01);
    expect(layer.active).toBe(26);
    layer.update(1);
    expect(layer.active).toBe(0);
  });

  it('spawns fewer particles when reduced motion is on', () => {
    let reduced = false;
    const layer = createEffectsLayer(
      () => reduced,
      () => 0.5
    );
    layer.spawn(kill);
    const normal = layer.active;
    layer.update(1);
    reduced = true;
    layer.spawn(kill);
    expect(layer.active).toBeLessThan(normal);
    expect(layer.active).toBeGreaterThan(0);
  });

  it('draws a beam as one line segment and then clears it', () => {
    const layer = createEffectsLayer(
      () => false,
      () => 0.5
    );
    layer.spawn(ballista);
    layer.update(0.01);
    const lines = layer.group.children[0] as unknown as {
      geometry: {drawRange: {count: number}};
    };
    expect(lines.geometry.drawRange.count).toBe(2);
    layer.update(0.5);
    expect(lines.geometry.drawRange.count).toBe(0);
  });

  it('draws mortar shells from the sim state and disposes cleanly', () => {
    const layer = createEffectsLayer(
      () => false,
      () => 0.5
    );
    layer.setShells([
      {x: 1, y: 1, targetId: 1, targetX: 2, targetY: 2, damage: 1, splash: 1},
    ]);
    const shells = layer.group.children[3] as unknown as {count: number};
    expect(shells.count).toBe(1);
    layer.setShells([]);
    expect(shells.count).toBe(0);
    expect(() => layer.dispose()).not.toThrow();
  });
});
