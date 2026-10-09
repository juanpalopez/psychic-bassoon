import type {BufferGeometry, Material, Object3D, Texture} from 'three';
import {Euler, Matrix4, Mesh, MeshLambertMaterial} from 'three';
import {mergeGeometries} from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import type {GlbPart, GlbUnit} from './manifest';

/** A loaded model: one merged geometry and the material to draw it with. */
export interface UnitModel {
  readonly geometry: BufferGeometry;
  readonly material: Material;
}

const KEPT_ATTRIBUTES = ['position', 'normal', 'uv'];

/**
 * Bakes every mesh of a loaded scene into plain geometries in the unit's
 * space: node transforms are applied (so a skinned character is frozen in
 * its rest pose), then the part's own turn, scale and offset.
 */
export function bakeGeometries(
  root: Object3D,
  part: GlbPart
): BufferGeometry[] {
  root.updateWorldMatrix(true, true);
  const scale = part.scale ?? 1;
  const place = new Matrix4()
    .makeRotationFromEuler(new Euler(0, part.rotationY ?? 0, 0))
    .multiply(new Matrix4().makeScale(scale, scale, scale));
  const [x, y, z] = part.position ?? [0, 0, 0];
  place.setPosition(x, y, z);

  const out: BufferGeometry[] = [];
  root.traverse(node => {
    if (!(node instanceof Mesh)) return;
    const geometry = node.geometry.index
      ? node.geometry.toNonIndexed()
      : node.geometry.clone();
    for (const name of Object.keys(geometry.attributes)) {
      if (!KEPT_ATTRIBUTES.includes(name)) geometry.deleteAttribute(name);
    }
    geometry.applyMatrix4(node.matrixWorld.clone().premultiply(place));
    out.push(geometry);
  });
  return out;
}

/** The colour texture of the first textured mesh in a scene, if any. */
export function findTexture(root: Object3D): Texture | undefined {
  let found: Texture | undefined;
  root.traverse(node => {
    if (found || !(node instanceof Mesh)) return;
    const material = Array.isArray(node.material)
      ? node.material[0]
      : node.material;
    const map = (material as {map?: Texture | null} | undefined)?.map;
    if (map) found = map;
  });
  return found;
}

/**
 * Builds a unit from its parts. `loadScene` fetches one GLB (a three.js
 * `Group`); injecting it keeps this testable without a browser.
 */
export async function buildGlbUnit(
  unit: GlbUnit,
  loadScene: (file: string) => Promise<Object3D>
): Promise<UnitModel> {
  const geometries: BufferGeometry[] = [];
  let texture: Texture | undefined;
  for (const part of unit.parts) {
    const scene = await loadScene(part.file);
    texture ??= findTexture(scene);
    geometries.push(...bakeGeometries(scene, part));
  }
  const geometry = mergeGeometries(geometries, false);
  for (const g of geometries) g.dispose();
  const material = new MeshLambertMaterial(
    texture ? {map: texture} : {color: 0xcccccc}
  );
  return {geometry, material};
}
