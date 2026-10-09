import {existsSync, readFileSync} from 'node:fs';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import {ENEMY_IDS, RULES, TOWER_IDS} from '../../content';
import {FOE_GLB, TOWER_GLB} from './manifest';
import type {GlbUnit} from './manifest';

const MODELS = 'public/assets/models';
const credits = readFileSync('assets/CREDITS.md', 'utf8');

/** Highest point of a GLB, from the POSITION bounds in its JSON chunk. */
function glbTop(file: string): number {
  const glb = readFileSync(join(MODELS, file));
  const json = JSON.parse(
    glb.subarray(20, 20 + glb.readUInt32LE(12)).toString('utf8')
  ) as {
    accessors: {max?: number[]}[];
    meshes: {primitives: {attributes: {POSITION: number}}[]}[];
  };
  return Math.max(
    ...json.meshes.flatMap(mesh =>
      mesh.primitives.map(
        p => json.accessors[p.attributes.POSITION]?.max?.[1] ?? 0
      )
    )
  );
}

/** Height of a whole unit: every part's own top, scaled and offset. */
function unitTop(unit: GlbUnit): number {
  return Math.max(
    ...unit.parts.map(
      p => (p.position?.[1] ?? 0) + glbTop(p.file) * (p.scale ?? 1)
    )
  );
}

const units: [string, GlbUnit][] = [
  ...ENEMY_IDS.flatMap(id =>
    FOE_GLB[id] ? [[id, FOE_GLB[id]] as [string, GlbUnit]] : []
  ),
  ...TOWER_IDS.flatMap(id =>
    Array.from({length: RULES.towerLevels}, (_, level) => {
      const unit = TOWER_GLB[id]?.(level);
      return unit ? ([`${id}:${level}`, unit] as [string, GlbUnit]) : undefined;
    }).filter((entry): entry is [string, GlbUnit] => entry !== undefined)
  ),
];

describe('model manifest', () => {
  it('has GLB models for the units we have assets for', () => {
    expect(units.length).toBeGreaterThanOrEqual(16);
  });

  it.each(units)(
    '%s: every file exists, is credited and shares one kit',
    (_name, unit) => {
      const kits = new Set(unit.parts.map(p => p.file.split('/')[0]));
      expect(kits.size).toBe(1); // parts of a unit share one texture
      for (const part of unit.parts) {
        expect(existsSync(join(MODELS, part.file))).toBe(true);
        expect(credits).toContain(`\`models/${part.file}\``);
      }
    }
  );

  it('makes each tower taller with every level', () => {
    for (const id of TOWER_IDS) {
      const factory = TOWER_GLB[id];
      if (!factory) continue;
      const tops = Array.from({length: RULES.towerLevels}, (_, level) =>
        unitTop(factory(level))
      );
      expect(tops[1]).toBeGreaterThan(tops[0] ?? 0);
      expect(tops[2]).toBeGreaterThan(tops[1] ?? 0);
    }
  });
});
