import {Box3} from 'three';
import {describe, expect, it} from 'vitest';
import {ENEMIES, ENEMY_IDS, RULES, TOWER_IDS} from '../../content';
import {FOE_MODELS, TOWER_MODELS} from './index';

const triangles = (g: {
  index: unknown;
  getAttribute: (n: string) => {count: number};
}) => g.getAttribute('position').count / 3;

describe('foe models', () => {
  it.each(ENEMY_IDS)('%s is one coloured geometry within budget', id => {
    const geometry = FOE_MODELS[id]();
    expect(geometry.getAttribute('position').count).toBeGreaterThan(0);
    expect(geometry.getAttribute('color').count).toBe(
      geometry.getAttribute('position').count
    );
    expect(geometry.getAttribute('normal')).toBeDefined();
    expect(triangles(geometry)).toBeLessThanOrEqual(400);
    geometry.dispose();
  });

  it.each(ENEMY_IDS)(
    '%s stands on the ground and is as wide as its body radius',
    id => {
      const geometry = FOE_MODELS[id]();
      geometry.computeBoundingBox();
      const box = geometry.boundingBox ?? new Box3();
      expect(box.min.y).toBeGreaterThanOrEqual(0);
      expect(box.min.y).toBeLessThan(0.1);
      const width = box.max.x - box.min.x;
      const r = ENEMIES[id].radius;
      expect(width).toBeGreaterThan(r * 1.2);
      expect(width).toBeLessThan(r * 3.2);
    }
  );

  it('gets bigger from Scamp to Warlord, so type reads from the silhouette', () => {
    const heights = ENEMY_IDS.map(id => {
      const g = FOE_MODELS[id]();
      g.computeBoundingBox();
      return g.boundingBox?.max.y ?? 0;
    });
    expect(heights).toEqual([...heights].sort((a, b) => a - b));
    expect(new Set(heights).size).toBe(heights.length);
  });
});

describe('tower models', () => {
  const levels = Array.from({length: RULES.towerLevels}, (_, i) => i);

  it.each(TOWER_IDS)('%s builds all three levels within budget', id => {
    for (const level of levels) {
      const geometry = TOWER_MODELS[id](level);
      expect(triangles(geometry)).toBeGreaterThan(0);
      expect(triangles(geometry)).toBeLessThanOrEqual(700);
      geometry.dispose();
    }
  });

  it.each(TOWER_IDS)('%s grows more detailed with each level', id => {
    const counts = levels.map(level => triangles(TOWER_MODELS[id](level)));
    expect(counts[1]).toBeGreaterThan(counts[0] ?? 0);
    expect(counts[2]).toBeGreaterThan(counts[1] ?? 0);
  });

  it.each(TOWER_IDS)('%s fits inside one cell', id => {
    const g = TOWER_MODELS[id](2);
    g.computeBoundingBox();
    const box = g.boundingBox ?? new Box3();
    expect(box.max.x - box.min.x).toBeLessThanOrEqual(1);
    expect(box.max.z - box.min.z).toBeLessThanOrEqual(1);
  });

  it('lights one more level pip per level', () => {
    const lit = (level: number) => {
      const g = TOWER_MODELS.ballista(level);
      const colors = g.getAttribute('color');
      let tinted = 0;
      for (let i = 0; i < colors.count; i++) {
        if (colors.getX(i) < 0.3 && colors.getY(i) > 0.8) tinted++;
      }
      return tinted;
    };
    expect(lit(1)).toBeGreaterThan(lit(0));
  });
});
