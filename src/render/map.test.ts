import {InstancedMesh, Matrix4, Vector3} from 'three';
import {describe, expect, it} from 'vitest';
import {GRID} from '../content';
import {generateMap} from '../sim';
import {createMapView, toWorld} from './map';
import {cellCentreWorld, worldFromSim} from './space';
import {simCellAt} from './space';

function cellsOf(mesh: InstancedMesh): string[] {
  const m = new Matrix4();
  const p = new Vector3();
  return Array.from({length: mesh.count}, (_, i) => {
    mesh.getMatrixAt(i, m);
    p.setFromMatrixPosition(m);
    const {col, row} = simCellAt(p.x, p.z);
    return `${col},${row}`;
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
    // the road runs left to right: the spawn is left of the board, the
    // Heartstone sits on the last cell
    const firstAt = cellCentreWorld(first?.col ?? 0, 0);
    expect(spawn?.position.z).toBe(firstAt.z);
    expect(spawn?.position.x).toBeLessThan(0.5);
    const lastAt = cellCentreWorld(last?.col ?? 0, last?.row ?? 0);
    expect([heartstone?.position.x, heartstone?.position.z]).toEqual([
      lastAt.x,
      lastAt.z,
    ]);
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
  it('maps a sim point to the turned world, on the ground', () => {
    const w = worldFromSim(2.5, 7.5);
    expect(toWorld({x: 2.5, y: 7.5})).toEqual({x: w.x, y: 0, z: w.z});
    expect(w).toEqual({x: 7.5, z: GRID.cols - 2.5});
  });
});
