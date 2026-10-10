import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';
import {buildFixtures, toBits} from './export-fixtures';

const files = buildFixtures();

describe('fixtures for the Godot port', () => {
  it.each(Object.keys(files))(
    '%s is up to date (run `pnpm fixtures` after a sim change)',
    name => {
      const committed = readFileSync(join('fixtures', name), 'utf8');
      expect(committed).toBe(files[name]);
    }
  );

  it('is reproducible: building twice gives the same text', () => {
    expect(buildFixtures()).toEqual(files);
  });

  it('holds only values Godot can compare exactly', () => {
    for (const text of Object.values(files)) {
      JSON.parse(text, (_key, value: unknown) => {
        if (typeof value === 'number') {
          expect(Number.isFinite(value)).toBe(true);
          expect(Object.is(value, -0)).toBe(false);
          if (Number.isInteger(value)) {
            expect(Math.abs(value)).toBeLessThan(2 ** 53);
          }
        }
        return value;
      });
    }
  });

  it('covers every foe, both routes and the replays', () => {
    const maps = JSON.parse(files['maps.json'] ?? '[]') as {
      routes: unknown[];
    }[];
    expect(maps.some(m => m.routes.length === 2)).toBe(true);
    expect(maps.some(m => m.routes.length === 1)).toBe(true);
    const replays = JSON.parse(files['replays.json'] ?? '[]') as {
      commands: unknown[];
      checkpoints: unknown[];
    }[];
    for (const r of replays) {
      expect(r.commands.length).toBeGreaterThan(10);
      expect(r.checkpoints.length).toBeGreaterThanOrEqual(5);
    }
    const waves = files['waves.json'] ?? '';
    for (const foe of ['scamp', 'raider', 'ironclad', 'warlord']) {
      expect(waves).toContain(`"${foe}"`);
    }
  });

  it('writes numbers as IEEE-754 bits and keeps other values', () => {
    expect(toBits(1.5)).toBe('3ff8000000000000');
    expect(toBits(0)).toBe('0000000000000000');
    expect(toBits([1, 'scamp', true, {a: 2}])).toEqual([
      '3ff0000000000000',
      'scamp',
      true,
      {a: '4000000000000000'},
    ]);
  });

  it('gives every float-carrying fixture a bits copy of the same shape', () => {
    const parse = (name: string): unknown => JSON.parse(files[name] ?? 'null');
    const same = (plain: unknown, bits: unknown) =>
      expect(bits).toEqual(toBits(plain));
    for (const e of parse('waves.json') as {waves: unknown; bits: unknown}[]) {
      same(e.waves, e.bits);
    }
    for (const e of parse('scaling.json') as {
      waves: unknown;
      bits: unknown;
    }[]) {
      same(e.waves, e.bits);
    }
    const {bits, ...cases} = parse('damage.json') as Record<string, unknown>;
    same(cases, bits);
    for (const e of parse('replays.json') as {
      checkpoints: unknown;
      checkpointsBits: unknown;
      final: unknown;
      finalBits: unknown;
    }[]) {
      same(e.checkpoints, e.checkpointsBits);
      same(e.final, e.finalBits);
    }
  });
});
