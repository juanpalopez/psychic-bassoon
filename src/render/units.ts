import {
  Group,
  InstancedMesh,
  Matrix4,
  MeshLambertMaterial,
  Object3D,
} from 'three';
import {ENEMY_IDS, GRID, RULES, TOWER_IDS} from '../content';
import type {EnemyId, TowerId} from '../content';
import {ROBOT_MODELS, TOWER_MODELS} from './models';

/** Most robots of one type drawn at once; the plan budgets about 80 in all. */
const ROBOT_CAPACITY = 128;
const LEVELS = RULES.towerLevels;

/** A robot as the layer draws it: where it is and which way it faces. */
export interface RobotPose {
  readonly type: EnemyId;
  readonly x: number;
  readonly y: number;
  /** Radians about the vertical axis; 0 faces +z. */
  readonly heading: number;
}

export interface TowerPose {
  readonly type: TowerId;
  readonly level: number;
  readonly col: number;
  readonly row: number;
}

export interface UnitLayer<T> {
  readonly group: Group;
  /** Re-places every instance. Allocates nothing. */
  update(poses: readonly T[]): void;
  dispose(): void;
}

function makeMesh(
  name: string,
  geometry: ConstructorParameters<typeof InstancedMesh>[0],
  material: MeshLambertMaterial,
  capacity: number
): InstancedMesh {
  const mesh = new InstancedMesh(geometry, material, capacity);
  mesh.name = name;
  mesh.count = 0;
  mesh.frustumCulled = false;
  return mesh;
}

/** One `InstancedMesh` per robot type, so 80 robots cost four draw calls. */
export function createRobotLayer(): UnitLayer<RobotPose> {
  const group = new Group();
  const material = new MeshLambertMaterial({vertexColors: true});
  const meshes = new Map<EnemyId, InstancedMesh>();
  for (const id of ENEMY_IDS) {
    const mesh = makeMesh(id, ROBOT_MODELS[id](), material, ROBOT_CAPACITY);
    meshes.set(id, mesh);
    group.add(mesh);
  }
  const dummy = new Object3D();
  return {
    group,
    update(poses) {
      for (const mesh of meshes.values()) mesh.count = 0;
      for (const pose of poses) {
        const mesh = meshes.get(pose.type);
        if (!mesh || mesh.count >= ROBOT_CAPACITY) continue;
        dummy.position.set(pose.x, 0.05, pose.y);
        dummy.rotation.y = pose.heading;
        dummy.updateMatrix();
        mesh.setMatrixAt(mesh.count++, dummy.matrix);
      }
      for (const mesh of meshes.values())
        mesh.instanceMatrix.needsUpdate = true;
    },
    dispose() {
      for (const mesh of meshes.values()) mesh.geometry.dispose();
      material.dispose();
    },
  };
}

/** One `InstancedMesh` per tower type and level: 12 draw calls at most. */
export function createTowerLayer(): UnitLayer<TowerPose> {
  const group = new Group();
  const material = new MeshLambertMaterial({vertexColors: true});
  const meshes = new Map<string, InstancedMesh>();
  const capacity = GRID.cols * GRID.rows;
  for (const id of TOWER_IDS) {
    for (let level = 0; level < LEVELS; level++) {
      const key = `${id}:${level}`;
      const mesh = makeMesh(key, TOWER_MODELS[id](level), material, capacity);
      meshes.set(key, mesh);
      group.add(mesh);
    }
  }
  const matrix = new Matrix4();
  return {
    group,
    update(poses) {
      for (const mesh of meshes.values()) mesh.count = 0;
      for (const pose of poses) {
        const mesh = meshes.get(`${pose.type}:${pose.level}`);
        if (!mesh || mesh.count >= capacity) continue;
        matrix.makeTranslation(
          pose.col + RULES.cellCentre,
          0.14,
          pose.row + RULES.cellCentre
        );
        mesh.setMatrixAt(mesh.count++, matrix);
      }
      for (const mesh of meshes.values())
        mesh.instanceMatrix.needsUpdate = true;
    },
    dispose() {
      for (const mesh of meshes.values()) mesh.geometry.dispose();
      material.dispose();
    },
  };
}
