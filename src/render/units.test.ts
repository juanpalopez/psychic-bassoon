import {InstancedMesh} from 'three';
import {describe, expect, it} from 'vitest';
import {createFoeLayer, createTowerLayer} from './units';
import type {FoePose} from './units';

const mesh = (
  group: {getObjectByName: (n: string) => unknown},
  name: string
) => {
  const found = group.getObjectByName(name);
  if (!(found instanceof InstancedMesh)) throw new Error(`no ${name}`);
  return found;
};

describe('foe layer', () => {
  it('draws 80 foes in four draw calls', () => {
    const layer = createFoeLayer();
    const types = ['scamp', 'raider', 'ironclad', 'warlord'] as const;
    const poses: FoePose[] = Array.from({length: 80}, (_, i) => ({
      type: types[i % 4] ?? 'raider',
      x: i * 0.1,
      y: 1,
      heading: 0,
    }));
    layer.update(poses);
    expect(layer.group.children).toHaveLength(4);
    const total = layer.group.children.reduce(
      (sum, c) => sum + (c as InstancedMesh).count,
      0
    );
    expect(total).toBe(80);
    expect(mesh(layer.group, 'scamp').count).toBe(20);
    layer.dispose();
  });

  it('drops foes that are gone on the next update', () => {
    const layer = createFoeLayer();
    layer.update([{type: 'raider', x: 1, y: 1, heading: 0}]);
    expect(mesh(layer.group, 'raider').count).toBe(1);
    layer.update([]);
    expect(mesh(layer.group, 'raider').count).toBe(0);
    layer.dispose();
  });

  it('places a foe at its position', () => {
    const layer = createFoeLayer();
    layer.update([{type: 'ironclad', x: 3.5, y: 6.25, heading: 0}]);
    const m = new Float32Array(16);
    mesh(layer.group, 'ironclad')
      .instanceMatrix.array.slice(0, 16)
      .forEach((v, i) => (m[i] = v));
    expect([m[12], m[14]]).toEqual([3.5, 6.25]);
    layer.dispose();
  });
});

describe('tower layer', () => {
  it('uses one mesh per type and level', () => {
    const layer = createTowerLayer();
    expect(layer.group.children).toHaveLength(12);
    layer.update([
      {type: 'ballista', level: 0, col: 1, row: 1},
      {type: 'ballista', level: 2, col: 2, row: 1},
      {type: 'stormSpire', level: 1, col: 3, row: 1},
    ]);
    expect(mesh(layer.group, 'ballista:0').count).toBe(1);
    expect(mesh(layer.group, 'ballista:2').count).toBe(1);
    expect(mesh(layer.group, 'stormSpire:1').count).toBe(1);
    expect(mesh(layer.group, 'frostSpire:0').count).toBe(0);
    layer.dispose();
  });
});
