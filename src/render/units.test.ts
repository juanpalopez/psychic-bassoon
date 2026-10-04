import {InstancedMesh} from 'three';
import {describe, expect, it} from 'vitest';
import {createRobotLayer, createTowerLayer} from './units';
import type {RobotPose} from './units';

const mesh = (
  group: {getObjectByName: (n: string) => unknown},
  name: string
) => {
  const found = group.getObjectByName(name);
  if (!(found instanceof InstancedMesh)) throw new Error(`no ${name}`);
  return found;
};

describe('robot layer', () => {
  it('draws 80 robots in four draw calls', () => {
    const layer = createRobotLayer();
    const types = ['skitter', 'hauler', 'smelter', 'overseer'] as const;
    const poses: RobotPose[] = Array.from({length: 80}, (_, i) => ({
      type: types[i % 4] ?? 'hauler',
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
    expect(mesh(layer.group, 'skitter').count).toBe(20);
    layer.dispose();
  });

  it('drops robots that are gone on the next update', () => {
    const layer = createRobotLayer();
    layer.update([{type: 'hauler', x: 1, y: 1, heading: 0}]);
    expect(mesh(layer.group, 'hauler').count).toBe(1);
    layer.update([]);
    expect(mesh(layer.group, 'hauler').count).toBe(0);
    layer.dispose();
  });

  it('places a robot at its position', () => {
    const layer = createRobotLayer();
    layer.update([{type: 'smelter', x: 3.5, y: 6.25, heading: 0}]);
    const m = new Float32Array(16);
    mesh(layer.group, 'smelter')
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
      {type: 'welder', level: 0, col: 1, row: 1},
      {type: 'welder', level: 2, col: 2, row: 1},
      {type: 'mainlineArc', level: 1, col: 3, row: 1},
    ]);
    expect(mesh(layer.group, 'welder:0').count).toBe(1);
    expect(mesh(layer.group, 'welder:2').count).toBe(1);
    expect(mesh(layer.group, 'mainlineArc:1').count).toBe(1);
    expect(mesh(layer.group, 'quenchCoil:0').count).toBe(0);
    layer.dispose();
  });
});
