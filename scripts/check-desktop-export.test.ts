import {spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dir = '';

function check(...args: string[]): number | null {
  return spawnSync('bash', ['scripts/check-desktop-export.sh', ...args], {
    encoding: 'utf8',
  }).status;
}

describe('desktop export check', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-export-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('accepts a binary with its .pck', () => {
    writeFileSync(join(dir, 'game.x86_64'), 'ELF binary');
    writeFileSync(join(dir, 'game.pck'), 'GDPC data');
    expect(check(join(dir, 'game.x86_64'))).toBe(0);
  });

  it('accepts a binary with the pck embedded', () => {
    writeFileSync(join(dir, 'game.exe'), 'MZ binary ... GDPC');
    expect(check(join(dir, 'game.exe'))).toBe(0);
  });

  it('rejects a binary with no pck', () => {
    writeFileSync(join(dir, 'game.x86_64'), 'ELF binary');
    expect(check(join(dir, 'game.x86_64'))).toBe(1);
  });

  it('rejects an empty .pck', () => {
    writeFileSync(join(dir, 'game.x86_64'), 'ELF binary');
    writeFileSync(join(dir, 'game.pck'), '');
    expect(check(join(dir, 'game.x86_64'))).toBe(1);
  });

  it('rejects a missing or empty binary', () => {
    writeFileSync(join(dir, 'game.pck'), 'GDPC data');
    expect(check(join(dir, 'game.x86_64'))).toBe(1);
    writeFileSync(join(dir, 'game.x86_64'), '');
    expect(check(join(dir, 'game.x86_64'))).toBe(1);
  });

  it('rejects a missing argument', () => {
    expect(check()).toBe(2);
  });
});
