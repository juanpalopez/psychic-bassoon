import {spawnSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dir: string;
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'purity-'));
  mkdirSync(join(dir, 'map'));
});
afterEach(() => rmSync(dir, {recursive: true, force: true}));

function check(source: string) {
  writeFileSync(join(dir, 'map', 'thing.gd'), source);
  const r = spawnSync('node', ['scripts/check-sim-purity.mjs', dir], {
    encoding: 'utf8',
  });
  return {status: r.status, output: r.stdout + r.stderr};
}

describe('check-sim-purity script', () => {
  it('passes a pure RefCounted class', () => {
    const source =
      'class_name Thing\nextends RefCounted\n\nfunc add(a: int, b: int) -> int:\n\treturn a + b\n';
    expect(check(source).status).toBe(0);
  });

  it.each([
    ['extends Node', 'extends Node\n'],
    ['extends Node3D', 'extends Node3D\n'],
    ['get_tree', 'func f():\n\tget_tree().quit()\n'],
    ['a node path', 'func f():\n\tvar n = $Child\n'],
    ['Engine', 'var fps = Engine.get_frames_per_second()\n'],
    ['Time', 'var t = Time.get_ticks_msec()\n'],
    ['OS', 'var n = OS.get_name()\n'],
    ['randf', 'var r = randf()\n'],
    ['randi', 'var r = randi() % 6\n'],
    ['randomize', 'func f():\n\trandomize()\n'],
    ['RandomNumberGenerator', 'var r = RandomNumberGenerator.new()\n'],
    ['round', 'var r = round(2.5)\n'],
    ['sin', 'var r = sin(1.0)\n'],
    ['pow', 'var r = pow(2.0, 3.0)\n'],
    ['a render import', 'const R = preload("res://render/x.gd")\n'],
  ])('rejects %s', (_name, source) => {
    const result = check(source);
    expect(result.status).toBe(1);
    expect(result.output).toContain('thing.gd');
  });

  it('ignores comments', () => {
    expect(
      check('# uses get_tree and randf in prose only\nvar x = 1\n').status
    ).toBe(0);
  });
});
