import {BoxGeometry, Group, Mesh, MeshStandardMaterial, Texture} from 'three';
import {describe, expect, it, vi} from 'vitest';
import {bakeGeometries, buildGlbUnit, findTexture} from './glb';

/** A 2 x 1 x 1 box standing on the ground, like a long siege engine. */
function longBox(): Group {
  const texture = new Texture();
  const mesh = new Mesh(
    new BoxGeometry(2, 1, 1).translate(0, 0.5, 0),
    new MeshStandardMaterial({map: texture})
  );
  mesh.position.set(0, 0, 0);
  const root = new Group();
  root.add(mesh);
  return root;
}

function bounds(geometry: {boundingBox: unknown; computeBoundingBox(): void}) {
  geometry.computeBoundingBox();
  const box = geometry.boundingBox as {
    min: {x: number; y: number; z: number};
    max: {x: number; y: number; z: number};
  };
  return box;
}

describe('bakeGeometries', () => {
  it('applies the part scale', () => {
    const [geometry] = bakeGeometries(longBox(), {file: 'x', scale: 0.5});
    const box = bounds(geometry as never);
    expect(box.max.x - box.min.x).toBeCloseTo(1, 6);
    expect(box.max.y).toBeCloseTo(0.5, 6);
  });

  it('turns the model about the vertical axis', () => {
    // -90 degrees takes +x to +z: the long side now runs along z
    const [geometry] = bakeGeometries(longBox(), {
      file: 'x',
      rotationY: -Math.PI / 2,
    });
    const box = bounds(geometry as never);
    expect(box.max.z - box.min.z).toBeCloseTo(2, 6);
    expect(box.max.x - box.min.x).toBeCloseTo(1, 6);
  });

  it('moves the part by its position', () => {
    const [geometry] = bakeGeometries(longBox(), {
      file: 'x',
      position: [0, 1, 0],
    });
    expect(bounds(geometry as never).min.y).toBeCloseTo(1, 6);
  });

  it('keeps only position, normal and uv', () => {
    const scene = longBox();
    const mesh = scene.children[0] as Mesh;
    mesh.geometry.setAttribute(
      'skinIndex',
      mesh.geometry.getAttribute('position').clone()
    );
    const [geometry] = bakeGeometries(scene, {file: 'x'});
    expect(Object.keys(geometry?.attributes ?? {}).sort()).toEqual([
      'normal',
      'position',
      'uv',
    ]);
  });

  it('does not change the loaded scene', () => {
    const scene = longBox();
    const mesh = scene.children[0] as Mesh;
    const before = mesh.geometry.getAttribute('position').array.slice();
    bakeGeometries(scene, {file: 'x', scale: 3});
    expect(Array.from(mesh.geometry.getAttribute('position').array)).toEqual(
      Array.from(before)
    );
  });
});

describe('findTexture', () => {
  it('finds the colour map of the first textured mesh', () => {
    expect(findTexture(longBox())).toBeInstanceOf(Texture);
    expect(findTexture(new Group())).toBeUndefined();
  });
});

describe('buildGlbUnit', () => {
  it('merges the parts of a unit into one geometry with their texture', async () => {
    const unit = await buildGlbUnit(
      {
        parts: [{file: 'a'}, {file: 'b', position: [0, 2, 0]}],
      },
      async () => longBox()
    );
    const box = bounds(unit.geometry as never);
    expect(box.max.y).toBeCloseTo(3, 6);
    expect((unit.material as unknown as {map: unknown}).map).toBeInstanceOf(
      Texture
    );
    expect(unit.geometry.getAttribute('position').count).toBe(72);
  });

  it('rejects when a file cannot be loaded', async () => {
    await expect(
      buildGlbUnit({parts: [{file: 'missing'}]}, () =>
        Promise.reject(new Error('404'))
      )
    ).rejects.toThrow('404');
  });

  it('rejects when parts cannot be merged (one has no uv), so the fallback runs', async () => {
    const withUv = longBox();
    const noUv = longBox();
    (noUv.children[0] as Mesh).geometry.deleteAttribute('uv');
    const warn = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    await expect(
      buildGlbUnit({parts: [{file: 'a'}, {file: 'b'}]}, async file =>
        file === 'a' ? withUv : noUv
      )
    ).rejects.toThrow('could not merge');
    warn.mockRestore();
  });

  it('tints the material so one palette can serve several units', async () => {
    const unit = await buildGlbUnit(
      {parts: [{file: 'a'}], tint: 0xffe08a},
      async () => longBox()
    );
    expect(
      (unit.material as unknown as {color: {getHex(): number}}).color.getHex()
    ).toBe(0xffe08a);
  });
});
