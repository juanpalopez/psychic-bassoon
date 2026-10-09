import {
  BoxGeometry,
  CylinderGeometry,
  DirectionalLight,
  Group,
  HemisphereLight,
  InstancedMesh,
  Matrix4,
  Mesh,
  MeshLambertMaterial,
  PlaneGeometry,
} from 'three';
import type {BufferGeometry, Material} from 'three';
import {GRID, RULES} from '../content';
import type {GameMap, Point} from '../sim';
import {PALETTE} from './palette';

const TILE_GAP = 0.06;
const PLATE_HEIGHT = 0.14;
const BELT_HEIGHT = 0.05;

/** Sim board coordinates (x right, y down) to world (x right, z toward you). */
export function toWorld(p: Point): {x: number; y: number; z: number} {
  return {x: p.x, y: 0, z: p.y};
}

export interface MapView {
  readonly group: Group;
  dispose(): void;
}

function instanced(
  name: string,
  geometry: BufferGeometry,
  material: Material,
  cells: readonly {col: number; row: number}[],
  y: number
): InstancedMesh {
  const mesh = new InstancedMesh(geometry, material, cells.length);
  mesh.name = name;
  const m = new Matrix4();
  cells.forEach(({col, row}, i) => {
    m.makeTranslation(col + RULES.cellCentre, y, row + RULES.cellCentre);
    mesh.setMatrixAt(i, m);
  });
  mesh.instanceMatrix.needsUpdate = true;
  return mesh;
}

/**
 * Builds the board from a sim map: ground, plots, road, spawn pad and Heartstone.
 * Read-only: it only reads the map and never touches game state.
 */
export function createMapView(map: GameMap): MapView {
  const group = new Group();
  group.name = 'map';
  const owned: {dispose(): void}[] = [];
  const own = <T extends {dispose(): void}>(item: T): T => {
    owned.push(item);
    return item;
  };

  const plots: {col: number; row: number}[] = [];
  const road: {col: number; row: number}[] = [];
  map.tiles.forEach((line, row) =>
    line.forEach((tile, col) =>
      (tile === 'plot' ? plots : road).push({col, row})
    )
  );

  const ground = new Mesh(
    own(new PlaneGeometry(GRID.cols + 12, GRID.rows + 12)),
    own(new MeshLambertMaterial({color: PALETTE.ground}))
  );
  ground.name = 'ground';
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(GRID.cols / 2, -0.01, GRID.rows / 2);
  group.add(ground);

  group.add(
    instanced(
      'plots',
      own(new BoxGeometry(1 - TILE_GAP, PLATE_HEIGHT, 1 - TILE_GAP)),
      own(new MeshLambertMaterial({color: PALETTE.plot})),
      plots,
      PLATE_HEIGHT / 2
    ),
    instanced(
      'road',
      own(new BoxGeometry(1, BELT_HEIGHT, 1)),
      own(new MeshLambertMaterial({color: PALETTE.road})),
      road,
      BELT_HEIGHT / 2
    )
  );

  const first = map.path[0];
  const last = map.path.at(-1);
  if (first && last) {
    const pad = (name: string, color: number, col: number, z: number) => {
      const marker = new Mesh(
        own(new CylinderGeometry(0.42, 0.42, 0.18, 20)),
        own(
          new MeshLambertMaterial({
            color,
            emissive: color,
            emissiveIntensity: 0.35,
          })
        )
      );
      marker.name = name;
      marker.position.set(col + RULES.cellCentre, 0.09, z);
      group.add(marker);
    };
    pad('spawn', PALETTE.spawn, first.col, -RULES.spawnOffset);
    pad('core', PALETTE.core, last.col, last.row + RULES.cellCentre);
  }

  const key = new DirectionalLight(0xffffff, 2.2);
  key.position.set(GRID.cols * 0.3, 14, GRID.rows + 6);
  group.add(key, new HemisphereLight(0x9fb4c8, 0x1a2029, 1.4));

  return {
    group,
    dispose() {
      for (const item of owned) item.dispose();
    },
  };
}
