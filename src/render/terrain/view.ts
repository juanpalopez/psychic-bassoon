import {Group, InstancedMesh, Mesh, Object3D} from 'three';
import {RULES} from '../../content';
import type {GameMap} from '../../sim';
import {addLights} from '../lights';
import type {MapView} from '../map';
import type {ModelLibrary} from '../models/library';
import {
  grassPlacements,
  roadPlacements,
  sceneryPlacements,
  TERRAIN,
} from './layout';
import type {Placement} from './layout';

/**
 * The rich map from Kenney tiles: grass on every plot, road tiles turned to
 * follow the route, a seeded ring of scenery, a spawn pad and the Heartstone
 * crystal. One instanced mesh per tile type. Returns undefined when a tile
 * failed to load, so the caller can use the primitive map instead.
 */
export function createTerrainView(
  map: GameMap,
  library: ModelLibrary
): MapView | undefined {
  if (!library.terrainReady) return undefined;
  const group = new Group();
  group.name = 'map';

  const placements: Placement[] = [
    ...grassPlacements(map),
    ...roadPlacements(map),
    ...sceneryPlacements(map.seed, TERRAIN.margin),
  ];
  const byFile = new Map<string, Placement[]>();
  for (const p of placements) {
    const list = byFile.get(p.file) ?? [];
    list.push(p);
    byFile.set(p.file, list);
  }

  const meshes: InstancedMesh[] = [];
  const dummy = new Object3D();
  for (const [file, list] of byFile) {
    const model = library.prop(file);
    if (!model) return undefined;
    const mesh = new InstancedMesh(model.geometry, model.material, list.length);
    mesh.name = file;
    list.forEach((p, i) => {
      dummy.position.set(p.col + RULES.cellCentre, 0, p.row + RULES.cellCentre);
      dummy.rotation.y = p.rotationY;
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    });
    mesh.instanceMatrix.needsUpdate = true;
    meshes.push(mesh);
    group.add(mesh);
  }

  const first = map.path[0];
  const last = map.path.at(-1);
  const place = (name: 'spawn' | 'heartstone', cell: typeof first) => {
    const model = library.extra(name);
    if (!model || !cell) return;
    const mesh = new Mesh(model.geometry, model.material);
    mesh.name = name;
    mesh.position.set(
      cell.col + RULES.cellCentre,
      0,
      cell.row + RULES.cellCentre
    );
    group.add(mesh);
  };
  place('spawn', first);
  place('heartstone', last);

  addLights(group);
  // geometries and materials belong to the model library
  return {group, dispose: () => meshes.forEach(m => m.dispose())};
}
