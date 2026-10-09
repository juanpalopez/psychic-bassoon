import {InstancedMesh, Matrix4, Vector3} from 'three';
import {describe, expect, it} from 'vitest';
import {GRID} from '../content';
import {generateMap} from '../sim';
import {createMapView, toWorld} from './map';

function cellsOf(mesh: InstancedMesh): string[] {
  const m = new Matrix4();
  const p = new Vector3();
  return Array.from({length: mesh.count}, (_, i) => {
    mesh.getMatrixAt(i, m);
    p.setFromMatrixPosition(m);
    return `${p.x - 0.5},${p.z - 0.5}`;
  }).sort();
}

describe('createMapView', () => {
  const map = generateMap(42);
  const view = createMapView(map);
  const find = (name: string) => {
    const found = view.group.getObjectByName(name);
    if (!(found instanceof InstancedMesh)) throw new Error(`no ${name}`);
    return found;
  };

  it('draws one tile per cell: the same plots and road as the sim map', () => {
    const plots: string[] = [];
    const road: string[] = [];
    map.tiles.forEach((line, row) =>
      line.forEach((tile, col) =>
        (tile === 'plot' ? plots : road).push(`${col},${row}`)
      )
    );
    expect(cellsOf(find('plots'))).toEqual(plots.sort());
    expect(cellsOf(find('road'))).toEqual(road.sort());
    expect(find('plots').count + find('road').count).toBe(
      GRID.cols * GRID.rows
    );
  });

  it('shows the same map for the same seed', () => {
    const again = createMapView(generateMap(42));
    const get = (v: typeof view, name: string) => {
      const mesh = v.group.getObjectByName(name);
      return mesh instanceof InstancedMesh ? cellsOf(mesh) : [];
    };
    expect(get(again, 'road')).toEqual(get(view, 'road'));
    expect(get(again, 'plots')).toEqual(get(view, 'plots'));
  });

  it('puts the spawn marker above the first path cell and the Heartstone on the last', () => {
    const first = map.path[0];
    const last = map.path.at(-1);
    const spawn = view.group.getObjectByName('spawn');
    const heartstone = view.group.getObjectByName('heartstone');
    expect(spawn?.position.x).toBe((first?.col ?? 0) + 0.5);
    expect(spawn?.position.z).toBeLessThan(0.5);
    expect(heartstone?.position.x).toBe((last?.col ?? 0) + 0.5);
    expect(heartstone?.position.z).toBe((last?.row ?? 0) + 0.5);
  });

  it('frees its geometry and materials on dispose', () => {
    let disposed = 0;
    view.group.traverse(o => {
      const mesh = o as InstancedMesh;
      mesh.geometry?.addEventListener('dispose', () => disposed++);
    });
    view.dispose();
    expect(disposed).toBeGreaterThan(0);
  });
});

describe('toWorld', () => {
  it('maps sim x to world x and sim y to world z, on the ground', () => {
    expect(toWorld({x: 2.5, y: 7.5})).toEqual({x: 2.5, y: 0, z: 7.5});
  });
});
