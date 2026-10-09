import {
  BoxGeometry,
  CylinderGeometry,
  Group,
  InstancedMesh,
  Matrix4,
  Mesh,
  MeshLambertMaterial,
  PlaneGeometry,
} from 'three';
import type {BufferGeometry, Material} from 'three';
import {RULES} from '../content';
import type {GameMap, Point} from '../sim';
import {GROUND_HEIGHT, ROAD_HEIGHT} from './heights';
import {addLights} from './lights';
import {BOARD_WORLD, cellCentreWorld, worldFromSim} from './space';
import {PALETTE} from './palette';

const TILE_GAP = 0.06;
const PLATE_HEIGHT = GROUND_HEIGHT;
const BELT_HEIGHT = ROAD_HEIGHT;

/** Sim board coordinates to world (the board is drawn turned a quarter). */
export function toWorld(p: Point): {x: number; y: number; z: number} {
  const w = worldFromSim(p.x, p.y);
  return {x: w.x, y: 0, z: w.z};
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
    const at = cellCentreWorld(col, row);
    m.makeTranslation(at.x, y, at.z);
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
    own(new PlaneGeometry(BOARD_WORLD.width + 12, BOARD_WORLD.depth + 12)),
    own(new MeshLambertMaterial({color: PALETTE.ground}))
  );
  ground.name = 'ground';
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(BOARD_WORLD.width / 2, -0.01, BOARD_WORLD.depth / 2);
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
    const pad = (name: string, color: number, simX: number, simY: number) => {
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
      const at = worldFromSim(simX, simY);
      marker.position.set(at.x, 0.09, at.z);
      group.add(marker);
    };
    pad(
      'spawn',
      PALETTE.spawn,
      first.col + RULES.cellCentre,
      -RULES.spawnOffset
    );
    pad(
      'heartstone',
      PALETTE.heartstone,
      last.col + RULES.cellCentre,
      last.row + RULES.cellCentre
    );
  }

  addLights(group);

  return {
    group,
    dispose() {
      for (const item of owned) item.dispose();
    },
  };
}
