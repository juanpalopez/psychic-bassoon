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
    ['extends Timer', 'extends Timer\n'],
    ['class_name with extends Control', 'class_name X extends Control\n'],
    ['get_tree', 'func f():\n\tget_tree().quit()\n'],
    ['get_node_or_null', 'func f():\n\tget_node_or_null("X")\n'],
    ['a node path', 'func f():\n\tvar n = $Child\n'],
    ['a unique node', 'func f():\n\tvar n = %Child\n'],
    ['Engine', 'var fps = Engine.get_frames_per_second()\n'],
    ['Time', 'var t = Time.get_ticks_msec()\n'],
    ['OS', 'var n = OS.get_name()\n'],
    ['Input', 'var p = Input.is_action_pressed("a")\n'],
    ['randf', 'var r = randf()\n'],
    ['randi', 'var r = randi() % 6\n'],
    ['randomize', 'func f():\n\trandomize()\n'],
    ['shuffle', 'func f():\n\tarr.shuffle()\n'],
    ['RandomNumberGenerator', 'var r = RandomNumberGenerator.new()\n'],
    ['round', 'var r = round(2.5)\n'],
    ['roundi', 'var r = roundi(2.5)\n'],
    ['sin', 'var r = sin(1.0)\n'],
    ['asin', 'var r = asin(0.5)\n'],
    ['pow', 'var r = pow(2.0, 3.0)\n'],
    ['.angle()', 'var a = Vector2(1, 2).angle()\n'],
    ['a render import', 'const R = preload("res://render/x.gd")\n'],
    ['an ui load', 'var r = load("res://ui/x.gd")\n'],
    ['an unknown class', 'var r = RenderFoo.new()\n'],
    [
      'a violation after a # inside a string',
      'func f():\n\tif t == "#": var f = randf()\n',
    ],
  ])('rejects %s', (_name, source) => {
    const result = check(source);
    expect(result.status).toBe(1);
    expect(result.output).toContain('thing.gd');
  });

  it('does not flag a $ or # inside a string, nor a modulo', () => {
    const source =
      'class_name Thing\nextends RefCounted\n\nconst ROAD := "#"\nfunc f(a: int, b: int) -> int:\n\tvar s := "cost: $" + str(a)\n\treturn a % b\n';
    expect(check(source).status).toBe(0);
  });

  it('lets a sim class extend another sim class and use enums', () => {
    writeFileSync(
      join(dir, 'map', 'base.gd'),
      'class_name Base\nextends RefCounted\nenum Kind {ROAD, PLOT}\n'
    );
    const source = 'class_name Child\nextends Base\nvar k: Kind = Kind.ROAD\n';
    expect(check(source).status).toBe(0);
  });

  it('ignores comments', () => {
    expect(
      check('# uses get_tree and randf in prose only\nvar x = 1\n').status
    ).toBe(0);
  });
});
