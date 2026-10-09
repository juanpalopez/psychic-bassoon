import type {BufferGeometry, Material, Object3D} from 'three';
import {MeshLambertMaterial} from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {ENEMY_IDS, RULES, TOWER_IDS} from '../../content';
import type {EnemyId, TowerId} from '../../content';
import {buildGlbUnit} from './glb';
import type {UnitModel} from './glb';
import {FOE_MODELS, TOWER_MODELS} from './index';
import {FOE_GLB, TOWER_GLB} from './manifest';

/**
 * Every unit's model, resolved once at start-up: the CC0 GLB when there is
 * one and it loaded, otherwise the primitive builder.
 */
export interface ModelLibrary {
  foe(id: EnemyId): UnitModel;
  tower(id: TowerId, level: number): UnitModel;
  /** Where each unit's model came from, for tests and the console. */
  readonly sources: Readonly<Record<string, 'glb' | 'primitive'>>;
  dispose(): void;
}

export type SceneLoader = (file: string) => Promise<Object3D>;

/** Loads GLB files from `base` (for example `/assets/models/`). */
export function glbSceneLoader(base: string): SceneLoader {
  const loader = new GLTFLoader();
  const cache = new Map<string, Promise<Object3D>>();
  return file => {
    let scene = cache.get(file);
    if (!scene) {
      scene = loader.loadAsync(`${base}${file}`).then(gltf => gltf.scene);
      cache.set(file, scene);
    }
    return scene;
  };
}

export async function loadModelLibrary(
  loadScene: SceneLoader
): Promise<ModelLibrary> {
  const primitiveMaterial = new MeshLambertMaterial({vertexColors: true});
  const disposables: {dispose(): void}[] = [primitiveMaterial];
  const foes = new Map<EnemyId, UnitModel>();
  const towers = new Map<string, UnitModel>();
  const sources: Record<string, 'glb' | 'primitive'> = {};

  const resolve = async (
    key: string,
    glb: Parameters<typeof buildGlbUnit>[0] | undefined,
    primitive: () => BufferGeometry
  ): Promise<UnitModel> => {
    if (glb) {
      try {
        const model = await buildGlbUnit(glb, loadScene);
        disposables.push(model.geometry, model.material);
        sources[key] = 'glb';
        return model;
      } catch (error) {
        console.warn(`model ${key} failed to load, using the primitive`, error);
      }
    }
    const geometry = primitive();
    disposables.push(geometry);
    sources[key] = 'primitive';
    return {geometry, material: primitiveMaterial as Material};
  };

  for (const id of ENEMY_IDS) {
    foes.set(id, await resolve(id, FOE_GLB[id], FOE_MODELS[id]));
  }
  for (const id of TOWER_IDS) {
    for (let level = 0; level < RULES.towerLevels; level++) {
      const glb = TOWER_GLB[id]?.(level);
      towers.set(
        `${id}:${level}`,
        await resolve(`${id}:${level}`, glb, () => TOWER_MODELS[id](level))
      );
    }
  }

  return {
    foe(id) {
      const model = foes.get(id);
      if (!model) throw new Error(`no model for ${id}`);
      return model;
    },
    tower(id, level) {
      const model = towers.get(`${id}:${level}`);
      if (!model) throw new Error(`no model for ${id} level ${level}`);
      return model;
    },
    sources,
    dispose() {
      for (const item of disposables) item.dispose();
    },
  };
}
