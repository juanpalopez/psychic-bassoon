import {describe, expect, it} from 'vitest';
import {buildGraph, select} from './select-tests.mjs';

// A small project: a map context, a combat context that uses it, a render script, and tests.
const files = new Map<string, string>([
  ['sim/map/grid.gd', 'class_name Grid\nextends RefCounted\n'],
  ['sim/combat/hit.gd', 'class_name Hit\nvar g: Grid\n'],
  ['render/view.gd', 'const H = preload("res://sim/combat/hit.gd")\n'],
  ['render/lonely.gd', 'extends Node\n'],
  ['ui/panel.tscn', '[ext_resource path="res://render/view.gd"]\n'],
  ['tests/sim/test_grid.gd', 'var g := Grid.new()\n'],
  ['tests/render/test_view.gd', 'var v = load("res://render/view.gd")\n'],
  ['tests/ui/test_panel.gd', 'var p = load("res://ui/panel.tscn")\n'],
  ['tests/test_everything.gd', 'var d = DirAccess.open("res://ui/")\n'],
]);
const graph = buildGraph(files);

describe('select-tests: what runs', () => {
  it('skips Godot for documentation-only changes', () => {
    expect(
      select(['docs/PLAN.md', 'README.md', 'site/index.html'], graph)
    ).toEqual({godot: false, gut: 'none'});
  });

  it.each([
    'scripts/check-sim-purity.mjs',
    'scripts/check-render-boundary.mjs',
    'package.json',
    'pnpm-lock.yaml',
    '.nvmrc',
  ])('keeps the Godot job for %s but runs no GUT test', path => {
    expect(select([path], graph)).toEqual({godot: true, gut: 'none'});
  });

  it('runs the tests that reach a changed class through class_name', () => {
    const result = select(['godot/sim/map/grid.gd'], graph);
    expect(result.godot).toBe(true);
    expect(result.gut.split(',')).toEqual([
      'res://tests/render/test_view.gd',
      'res://tests/sim/test_grid.gd',
      'res://tests/test_everything.gd',
      'res://tests/ui/test_panel.gd',
    ]);
  });

  it('follows preload and scene references and directory references', () => {
    const result = select(['godot/render/view.gd'], graph);
    expect(result.gut.split(',')).toEqual([
      'res://tests/render/test_view.gd',
      'res://tests/test_everything.gd',
      'res://tests/ui/test_panel.gd',
    ]);
  });

  it('follows a directory reference to every file below it', () => {
    expect(select(['godot/ui/panel.tscn'], graph).gut.split(',')).toEqual([
      'res://tests/test_everything.gd',
      'res://tests/ui/test_panel.gd',
    ]);
  });

  it('runs a changed test script on its own', () => {
    expect(select(['godot/tests/sim/test_grid.gd'], graph).gut).toBe(
      'res://tests/sim/test_grid.gd'
    );
  });

  it('keeps the Godot job for .uid files but selects no test from them', () => {
    expect(select(['godot/sim/map/grid.gd.uid', 'docs/a.md'], graph)).toEqual({
      godot: true,
      gut: 'none',
    });
  });

  it.each([
    'godot/content/towers.gd',
    'godot/sim/rng.gd',
    'godot/sim/streams.gd',
    'godot/sim/game/game.gd',
    'godot/tests/goldens/run.json',
    'godot/project.godot',
    'godot/assets/models/a.glb',
    'fixtures/maps.json',
    '.github/workflows/ci.yml',
    '.godot-version',
    'scripts/select-tests.mjs',
  ])('runs everything for %s', path => {
    expect(select([path], graph)).toEqual({godot: true, gut: 'all'});
  });

  it('runs everything for a file the graph does not know (deleted or new)', () => {
    expect(select(['godot/render/deleted.gd'], graph).gut).toBe('all');
  });

  it('runs everything for a changed file no test reaches', () => {
    expect(select(['godot/render/lonely.gd'], graph).gut).toBe('all');
  });

  it('keeps one full trigger enough among many small changes', () => {
    expect(
      select(['godot/render/view.gd', 'godot/sim/rng.gd'], graph).gut
    ).toBe('all');
  });
});
