import {
  BoxGeometry,
  ConeGeometry,
  CylinderGeometry,
  Euler,
  Float32BufferAttribute,
  Matrix4,
  SphereGeometry,
  TorusGeometry,
} from 'three';
import type {BufferGeometry} from 'three';
import {mergeGeometries} from 'three/examples/jsm/utils/BufferGeometryUtils.js';

/** A primitive with a colour and a place in the unit's local space. */
export interface Part {
  readonly geometry: BufferGeometry;
  readonly color: number;
  readonly position?: readonly [number, number, number];
  /** Euler rotation in radians (x, y, z). */
  readonly rotation?: readonly [number, number, number];
}

export const box = (w: number, h: number, d: number) =>
  new BoxGeometry(w, h, d);
export const cylinder = (top: number, bottom: number, h: number, sides = 10) =>
  new CylinderGeometry(top, bottom, h, sides);
export const cone = (radius: number, h: number, sides = 8) =>
  new ConeGeometry(radius, h, sides);
export const sphere = (radius: number) => new SphereGeometry(radius, 8, 6);
export const ring = (radius: number, tube: number) =>
  new TorusGeometry(radius, tube, 4, 10);

/**
 * Merges primitives into one geometry with a vertex colour per part, so a
 * whole unit is a single draw call and a single shared material.
 */
export function compose(parts: readonly Part[]): BufferGeometry {
  const baked = parts.map(part => {
    const geometry = part.geometry.index
      ? part.geometry.toNonIndexed()
      : part.geometry.clone();
    const [rx, ry, rz] = part.rotation ?? [0, 0, 0];
    const [x, y, z] = part.position ?? [0, 0, 0];
    geometry.applyMatrix4(
      new Matrix4()
        .makeRotationFromEuler(new Euler(rx, ry, rz))
        .setPosition(x, y, z)
    );
    const count = geometry.getAttribute('position').count;
    const r = ((part.color >> 16) & 255) / 255;
    const g = ((part.color >> 8) & 255) / 255;
    const b = (part.color & 255) / 255;
    const colors = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) colors.set([r, g, b], i * 3);
    geometry.setAttribute('color', new Float32BufferAttribute(colors, 3));
    geometry.deleteAttribute('uv');
    part.geometry.dispose();
    return geometry;
  });
  const merged = mergeGeometries(baked, false);
  for (const geometry of baked) geometry.dispose();
  return merged;
}
