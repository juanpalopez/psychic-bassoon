import {spawnSync} from 'node:child_process';
import {randomFillSync} from 'node:crypto';
import {mkdirSync, mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dist: string;

beforeEach(() => {
  dist = mkdtempSync(join(tmpdir(), 'check-size-'));
});

afterEach(() => {
  rmSync(dist, {recursive: true, force: true});
});

function run(dir: string) {
  const result = spawnSync('node', ['scripts/check-size.mjs', dir], {
    encoding: 'utf8',
  });
  return {status: result.status, output: result.stdout + result.stderr};
}

function writeRandom(path: string, bytes: number): void {
  writeFileSync(path, randomFillSync(Buffer.alloc(bytes)));
}

describe('check-size script', () => {
  it('passes a small bundle', () => {
    mkdirSync(join(dist, 'assets'));
    writeFileSync(join(dist, 'assets', 'index.js'), 'console.log(1);\n');
    expect(run(dist).status).toBe(0);
  });

  it('counts .mjs files in nested folders', () => {
    mkdirSync(join(dist, 'assets', 'nested'), {recursive: true});
    writeRandom(join(dist, 'assets', 'nested', 'big.mjs'), 1_500_000);
    const result = run(dist);
    expect(result.status).toBe(1);
    expect(result.output).toContain('budget exceeded');
  });

  it('ignores a directory whose name ends in .js', () => {
    mkdirSync(join(dist, 'vendor.js'));
    writeFileSync(join(dist, 'vendor.js', 'a.js'), 'console.log(1);\n');
    expect(run(dist).status).toBe(0);
  });

  it('fails with a message when there is no JavaScript', () => {
    const result = run(dist);
    expect(result.status).toBe(1);
    expect(result.output).toContain('No JS files found');
  });

  it('fails with a message when the directory does not exist', () => {
    const result = run(join(dist, 'missing'));
    expect(result.status).toBe(1);
    expect(result.output).toContain('is not a directory');
    expect(result.output).not.toContain('at ');
  });
});
