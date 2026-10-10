import {spawnSync} from 'node:child_process';
import {randomFillSync} from 'node:crypto';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dir: string;
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'godot-size-'));
});
afterEach(() => rmSync(dir, {recursive: true, force: true}));

const run = () => {
  const r = spawnSync('node', ['scripts/check-godot-size.mjs', dir], {
    encoding: 'utf8',
  });
  return {status: r.status, output: r.stdout + r.stderr};
};

describe('check-godot-size script', () => {
  it('passes a small export', () => {
    writeFileSync(join(dir, 'index.wasm'), 'wasm');
    writeFileSync(join(dir, 'index.js'), 'js');
    expect(run().status).toBe(0);
  });

  it('fails over the download budget (incompressible data)', () => {
    writeFileSync(
      join(dir, 'index.wasm'),
      randomFillSync(Buffer.alloc(15_000_000))
    );
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('budget exceeded');
  });

  it('fails when there is no wasm', () => {
    writeFileSync(join(dir, 'index.js'), 'js');
    expect(run().status).toBe(1);
  });

  it('fails when the folder is missing', () => {
    rmSync(dir, {recursive: true, force: true});
    expect(run().status).toBe(1);
  });
});
