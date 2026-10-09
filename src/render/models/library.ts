import type {BufferGeometry, Material, Object3D, Texture} from 'three';
import {MeshLambertMaterial} from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {MeshoptDecoder} from 'three/examples/jsm/libs/meshopt_decoder.module.js';
import {ENEMY_IDS, RULES, TOWER_IDS} from '../../content';
import type {EnemyId, TowerId} from '../../content';
import {buildGlbUnit} from './glb';
import type {UnitModel} from './glb';
import type {GlbUnit} from './manifest';
import {FOE_MODELS, TOWER_MODELS} from './index';
import {EXTRA_GLB, FOE_GLB, TOWER_GLB} from './manifest';
import {TERRAIN_FILES} from '../terrain/layout';

/**
 * Every unit's model, resolved once at start-up: the CC0 GLB when there is
 * one and it loaded, otherwise the primitive builder.
 */
export interface ModelLibrary {
  foe(id: EnemyId): UnitModel;
  tower(id: TowerId, level: number): UnitModel;
  /** A single scenery tile, or undefined if it failed to load. */
  prop(file: string): UnitModel | undefined;
  /** The spawn pad and the Heartstone crystal, if they loaded. */
  extra(name: 'spawn' | 'heartstone'): UnitModel | undefined;
  /** True when every terrain tile loaded, so the rich map can be drawn. */
  readonly terrainReady: boolean;
  /** Where each unit's model came from, for tests and the console. */
  readonly sources: Readonly<Record<string, 'glb' | 'primitive'>>;
  dispose(): void;
}

export type SceneLoader = (file: string) => Promise<Object3D>;

/** Loads GLB files from `base` (for example `/assets/models/`). */
export function glbSceneLoader(base: string): SceneLoader {
  const loader = new GLTFLoader();
  // so compressed GLBs (meshopt) load too once we ship them
  loader.setMeshoptDecoder(MeshoptDecoder);
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

/** A slow connection must never leave the player on a blank screen. */
const DEFAULT_TIMEOUT_MS = 8000;

export interface LibraryOptions {
  /** Units still loading after this long use their primitive instead. */
  readonly timeoutMs?: number;
}

export async function loadModelLibrary(
  loadScene: SceneLoader,
  {timeoutMs = DEFAULT_TIMEOUT_MS}: LibraryOptions = {}
): Promise<ModelLibrary> {
  const primitiveMaterial = new MeshLambertMaterial({vertexColors: true});
  const disposables: {dispose(): void}[] = [primitiveMaterial];
  const foes = new Map<EnemyId, UnitModel>();
  const towers = new Map<string, UnitModel>();
  const sources: Record<string, 'glb' | 'primitive'> = {};
  const props = new Map<string, UnitModel>();
  const extras = new Map<string, UnitModel>();

  /** Loads a GLB unit that has no primitive; undefined on any failure. */
  const loadOptional = async (
    key: string,
    unit: GlbUnit
  ): Promise<UnitModel | undefined> => {
    try {
      const model = await withTimeout(buildGlbUnit(unit, loadScene));
      disposables.push(model.geometry, model.material);
      const map = (model.material as {map?: Texture | null}).map;
      if (map) disposables.push(map);
      sources[key] = 'glb';
      return model;
    } catch (error) {
      console.warn(`model ${key} failed to load, skipping it`, error);
      return undefined;
    }
  };

  const withTimeout = <T>(promise: Promise<T>): Promise<T> =>
    new Promise<T>((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error(`timed out after ${timeoutMs} ms`)),
        timeoutMs
      );
      promise.then(
        value => {
          clearTimeout(timer);
          resolve(value);
        },
        error => {
          clearTimeout(timer);
          reject(error);
        }
      );
    });

  const resolve = async (
    key: string,
    glb: GlbUnit | undefined,
    primitive: () => BufferGeometry
  ): Promise<UnitModel> => {
    if (glb) {
      try {
        const model = await withTimeout(buildGlbUnit(glb, loadScene));
        disposables.push(model.geometry, model.material);
        const map = (model.material as {map?: Texture | null}).map;
        if (map) disposables.push(map);
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

  // all units load in parallel, so the slowest one sets the wait
  await Promise.all([
    ...TERRAIN_FILES.map(async file => {
      const model = await loadOptional(`terrain:${file}`, {parts: [{file}]});
      if (model) props.set(file, model);
    }),
    ...(['spawn', 'heartstone'] as const).map(async name => {
      const model = await loadOptional(`extra:${name}`, EXTRA_GLB[name]);
      if (model) extras.set(name, model);
    }),
    ...ENEMY_IDS.map(async id => {
      foes.set(id, await resolve(id, FOE_GLB[id], FOE_MODELS[id]));
    }),
    ...TOWER_IDS.flatMap(id =>
      Array.from({length: RULES.towerLevels}, async (_, level) => {
        towers.set(
          `${id}:${level}`,
          await resolve(`${id}:${level}`, TOWER_GLB[id]?.(level), () =>
            TOWER_MODELS[id](level)
          )
        );
      })
    ),
  ]);

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
    prop: file => props.get(file),
    extra: name => extras.get(name),
    terrainReady: TERRAIN_FILES.every(f => props.has(f)),
    sources,
    dispose() {
      for (const item of disposables) item.dispose();
    },
  };
}
