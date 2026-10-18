import {execFileSync, spawnSync} from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {describe, expect, it} from 'vitest';
import {
  countProduction,
  isProduction,
  LIMIT,
  report,
  verdict,
  WARN_ABOVE,
} from './check-pr-size.mjs';

// One `git diff --numstat -z` record per [added, deleted, path].
function numstat(rows: [string, string, string][]): string {
  return rows.map(([a, d, p]) => `${a}\t${d}\t${p}\0`).join('');
}

describe('check-pr-size: what counts', () => {
  it.each([
    'godot/sim/map/map_gen.gd',
    'godot/render/paper/painted.gdshader',
    'godot/render/paper/painted.gdshaderinc',
    'godot/main.tscn',
    'godot/ui/tower_panel.tres',
    'godot/project.godot',
    'godot/export_presets.cfg',
    'scripts/check-assets.mjs',
    'scripts/tool.ts',
    'scripts/tool.cjs',
    'scripts/tool.mts',
    'scripts/ios-run.sh',
    '.github/workflows/ci.yml',
    '.github/workflows/x.yaml',
    'e2e_tools/x.ts',
  ])('counts production code: %s', path => {
    expect(isProduction(path)).toBe(true);
  });

  it.each([
    'godot/tests/sim/test_route.gd',
    'godot/tests/goldens/replays.json',
    'godot/addons/gut/gut.gd',
    'godot/ui/hud_theme.tres',
    'scripts/check-assets.test.ts',
    'scripts/check-pr-size.d.mts',
    'scripts/mutations/valley-map.json',
    'docs/PLAN.md',
    'CLAUDE.md',
    'fixtures/maps.json',
    'godot/assets/models/towers/spool_guard.glb',
    'godot/assets/x.tscn',
    'godot/assets/app/icon.png.import',
    'godot/render/board.gd.uid',
    'assets-src/diorama_lookdev/diorama_lookdev.py',
    'prototype/x.js',
    'e2e-godot/smoke.spec.ts',
    'pnpm-lock.yaml',
  ])('does not count: %s', path => {
    expect(isProduction(path)).toBe(false);
  });
});

describe('check-pr-size: totals', () => {
  it('sums added and deleted production lines and skips the rest', () => {
    const {total, files} = countProduction(
      numstat([
        ['120', '30', 'godot/sim/map/terrain_gen.gd'],
        ['400', '0', 'godot/tests/sim/test_terrain.gd'],
        ['10', '5', 'docs/PLAN.md'],
        ['7', '3', 'scripts/new.mjs'],
      ])
    );
    expect(total).toBe(160);
    expect(files.map(f => f.path)).toEqual([
      'godot/sim/map/terrain_gen.gd',
      'scripts/new.mjs',
    ]);
  });

  it('counts a production file git calls binary as over the limit', () => {
    expect(countProduction(numstat([['-', '-', 'godot/sim/x.gd']])).total).toBe(
      LIMIT + 1
    );
    expect(
      countProduction(numstat([['-', '-', 'godot/assets/a.png']])).total
    ).toBe(0);
  });

  it('reads paths with tabs or non-ASCII letters as they are (no quoting with -z)', () => {
    const {total} = countProduction(
      numstat([['50', '0', 'godot/sim/mapé.gd']])
    );
    expect(total).toBe(50);
  });
});

describe('check-pr-size: verdicts and exit codes', () => {
  it('passes small PRs, warns near the limit and fails above it', () => {
    expect(verdict(WARN_ABOVE)).toBe('ok');
    expect(verdict(WARN_ABOVE + 1)).toBe('warn');
    expect(verdict(LIMIT)).toBe('warn');
    expect(verdict(LIMIT + 1)).toBe('fail');
  });

  it('exits 1 above the limit and 0 with the size-exception label', () => {
    const big = numstat([['301', '0', 'godot/sim/x.gd']]);
    expect(report(big).code).toBe(1);
    expect(report(big).lines.at(-1)).toMatch(/::error::/);
    expect(report(big, true).code).toBe(0);
    expect(report(big, true).lines.at(-1)).toMatch(/size-exception/);
    expect(report(numstat([['300', '0', 'godot/sim/x.gd']])).code).toBe(0);
  });
});

describe('check-pr-size: on a real repository', () => {
  const script = resolve('scripts/check-pr-size.mjs');
  function repo(): {dir: string; git: (...a: string[]) => string} {
    const dir = mkdtempSync(join(tmpdir(), 'pr-size-'));
    const git = (...args: string[]) =>
      execFileSync('git', args, {cwd: dir, encoding: 'utf8'}).trim();
    git('init', '-q', '-b', 'main');
    git('config', 'user.email', 't@example.com');
    git('config', 'user.name', 't');
    writeFileSync(join(dir, 'README.md'), 'x\n');
    git('add', '-A');
    git('commit', '-q', '-m', 'base');
    return {dir, git};
  }
  const lines = (n: number) =>
    Array.from({length: n}, (_, i) => `var a${i} := ${i}`).join('\n');
  function check(
    dir: string,
    base: string,
    head: string,
    ...flags: string[]
  ): number | null {
    return spawnSync('node', [script, base, head, ...flags], {
      cwd: dir,
      encoding: 'utf8',
    }).status;
  }

  it('fails a code change hidden from diffs by a -diff attribute', () => {
    const {dir, git} = repo();
    const base = git('rev-parse', 'HEAD');
    mkdirSync(join(dir, 'godot/sim'), {recursive: true});
    writeFileSync(join(dir, '.gitattributes'), '*.gd -diff\n');
    writeFileSync(join(dir, 'godot/sim/big.gd'), lines(400));
    git('add', '-A');
    git('commit', '-q', '-m', 'hide');
    expect(check(dir, base, git('rev-parse', 'HEAD'))).toBe(1);
    rmSync(dir, {recursive: true, force: true});
  });

  it('counts code moved out of a test folder into production in full', () => {
    const {dir, git} = repo();
    mkdirSync(join(dir, 'godot/tests'), {recursive: true});
    writeFileSync(join(dir, 'godot/tests/helper.gd'), lines(400));
    git('add', '-A');
    git('commit', '-q', '-m', 'test helper');
    const base = git('rev-parse', 'HEAD');
    mkdirSync(join(dir, 'godot/sim'), {recursive: true});
    git('mv', 'godot/tests/helper.gd', 'godot/sim/helper.gd');
    git('commit', '-q', '-m', 'move');
    expect(check(dir, base, git('rev-parse', 'HEAD'))).toBe(1);
    rmSync(dir, {recursive: true, force: true});
  });

  it('lets a 301-line change through only with --allow', () => {
    const {dir, git} = repo();
    const base = git('rev-parse', 'HEAD');
    mkdirSync(join(dir, 'godot/sim'), {recursive: true});
    writeFileSync(join(dir, 'godot/sim/big.gd'), lines(301) + '\n');
    git('add', '-A');
    git('commit', '-q', '-m', 'big');
    const head = git('rev-parse', 'HEAD');
    expect(check(dir, base, head)).toBe(1);
    expect(check(dir, base, head, '--allow')).toBe(0);
    rmSync(dir, {recursive: true, force: true});
  });

  it('runs the check from a path with a space through a symlink', () => {
    const {dir, git} = repo();
    const base = git('rev-parse', 'HEAD');
    mkdirSync(join(dir, 'godot/sim'), {recursive: true});
    writeFileSync(join(dir, 'godot/sim/big.gd'), lines(400));
    git('add', '-A');
    git('commit', '-q', '-m', 'big');
    const spaced = mkdtempSync(join(tmpdir(), 'pr size '));
    const copy = join(spaced, 'check.mjs');
    writeFileSync(copy, readFileSync(script));
    const link = join(spaced, 'link.mjs');
    symlinkSync(copy, link);
    for (const path of [copy, link]) {
      const run = spawnSync('node', [path, base, git('rev-parse', 'HEAD')], {
        cwd: dir,
        encoding: 'utf8',
      });
      expect(run.status).toBe(1);
      expect(run.stdout).toMatch(/Production lines changed: 400/);
    }
    rmSync(spaced, {recursive: true, force: true});
    rmSync(dir, {recursive: true, force: true});
  });

  it('passes a small change', () => {
    const {dir, git} = repo();
    const base = git('rev-parse', 'HEAD');
    mkdirSync(join(dir, 'godot/sim'), {recursive: true});
    writeFileSync(join(dir, 'godot/sim/small.gd'), lines(40));
    git('add', '-A');
    git('commit', '-q', '-m', 'small');
    expect(check(dir, base, git('rev-parse', 'HEAD'))).toBe(0);
    rmSync(dir, {recursive: true, force: true});
  });
});
