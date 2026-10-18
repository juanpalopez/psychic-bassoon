import {describe, expect, it} from 'vitest';
import {
  countProduction,
  isProduction,
  LIMIT,
  verdict,
  WARN_ABOVE,
} from './check-pr-size.mjs';

describe('check-pr-size', () => {
  it.each([
    'godot/sim/map/map_gen.gd',
    'godot/render/paper/painted.gdshader',
    'godot/render/paper/painted.gdshaderinc',
    'godot/main.tscn',
    'godot/project.godot',
    'godot/export_presets.cfg',
    'godot/content/towers.gd',
    'scripts/check-assets.mjs',
    'scripts/ios-run.sh',
    '.github/workflows/ci.yml',
  ])('counts production code: %s', path => {
    expect(isProduction(path)).toBe(true);
  });

  it.each([
    'godot/tests/sim/test_route.gd',
    'godot/tests/goldens/replays.json',
    'godot/addons/gut/gut.gd',
    'scripts/check-assets.test.ts',
    'scripts/mutations/valley-map.json',
    'docs/PLAN.md',
    'CLAUDE.md',
    'fixtures/maps.json',
    'godot/assets/models/towers/spool_guard.glb',
    'godot/assets/app/icon.png.import',
    'godot/render/board.gd.uid',
    'assets-src/diorama_lookdev/diorama_lookdev.py',
    'pnpm-lock.yaml',
    'docs/lessons/README.md',
  ])('does not count: %s', path => {
    expect(isProduction(path)).toBe(false);
  });

  it('sums added and deleted production lines and skips the rest', () => {
    const numstat = [
      '120\t30\tgodot/sim/map/terrain_gen.gd',
      '400\t0\tgodot/tests/sim/test_terrain.gd',
      '10\t5\tdocs/PLAN.md',
      '-\t-\tgodot/assets/app/icon.png',
      '7\t3\tgodot/{icon.png.import => assets/app/icon.png.import}',
      '2\t2\tscripts/{old.mjs => new.mjs}',
      '',
    ].join('\n');
    const {total, files} = countProduction(numstat);
    expect(total).toBe(154);
    expect(files.map(f => f.path)).toEqual([
      'godot/sim/map/terrain_gen.gd',
      'scripts/new.mjs',
    ]);
  });

  it('passes small PRs, warns near the limit and fails above it', () => {
    expect(verdict(WARN_ABOVE)).toBe('ok');
    expect(verdict(WARN_ABOVE + 1)).toBe('warn');
    expect(verdict(LIMIT)).toBe('warn');
    expect(verdict(LIMIT + 1)).toBe('fail');
  });

  it('lets the size-exception label allow a larger PR, with a warning', () => {
    expect(verdict(LIMIT + 500, true)).toBe('warn');
    expect(verdict(10, true)).toBe('ok');
  });
});
