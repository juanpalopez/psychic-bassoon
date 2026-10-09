import {BoxGeometry, Group, Mesh, MeshStandardMaterial, Texture} from 'three';
import {describe, expect, it, vi} from 'vitest';
import {ENEMY_IDS, RULES, TOWER_IDS} from '../../content';
import {FOE_GLB} from './manifest';
import {loadModelLibrary} from './library';

function scene(): Group {
  const root = new Group();
  root.add(
    new Mesh(
      new BoxGeometry(1, 1, 1),
      new MeshStandardMaterial({map: new Texture()})
    )
  );
  return root;
}

describe('loadModelLibrary', () => {
  it('uses a GLB where the manifest has one and primitives elsewhere', async () => {
    const lib = await loadModelLibrary(async () => scene());
    for (const id of ENEMY_IDS) {
      expect(lib.sources[id]).toBe(FOE_GLB[id] ? 'glb' : 'primitive');
    }
    expect(lib.foe('ironclad').geometry.getAttribute('uv')).toBeDefined();
    lib.dispose();
  });

  it('falls back to the primitive when a file fails to load', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
    const lib = await loadModelLibrary(() => Promise.reject(new Error('404')));
    expect(Object.values(lib.sources).every(s => s === 'primitive')).toBe(true);
    expect(lib.foe('ironclad').geometry.getAttribute('color')).toBeDefined();
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
    lib.dispose();
  });

  it('has a model for every foe and every tower level', async () => {
    const lib = await loadModelLibrary(() =>
      Promise.reject(new Error('offline'))
    );
    for (const id of ENEMY_IDS) expect(lib.foe(id).geometry).toBeDefined();
    for (const id of TOWER_IDS) {
      for (let level = 0; level < RULES.towerLevels; level++) {
        expect(lib.tower(id, level).geometry).toBeDefined();
      }
    }
    lib.dispose();
  });
});
