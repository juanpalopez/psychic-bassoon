import {spawnSync} from 'node:child_process';
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dir = '';

const A = 'res://tests/test_heartstone_name.gd';
const B = 'res://tests/ui/test_fps_text.gd';

/**
 * Runs the runner with a fake Godot that records the -gtest value it was given and prints a GUT
 * summary: a failing one for a script whose path contains `fps`, a passing one otherwise.
 */
function run(...args: string[]): {
  status: number | null;
  out: string;
  ran: string[];
} {
  const fake = join(dir, 'godot');
  const record = join(dir, 'ran.txt');
  writeFileSync(
    fake,
    [
      '#!/usr/bin/env bash',
      'for a in "$@"; do',
      '  case "$a" in -gtest=*) t="${a#-gtest=}" ;; esac',
      'done',
      '[ -n "${t:-}" ] || exit 0',
      `echo "$t" >> "${record}"`,
      'case "$t" in',
      '  *fps*) echo "Failing Tests  1"; echo "Failed: test_x" ;;',
      '  *) echo "Passing Tests  2" ;;',
      'esac',
      '',
    ].join('\n')
  );
  chmodSync(fake, 0o755);
  const r = spawnSync('bash', ['scripts/run-gut-parallel.sh', ...args], {
    encoding: 'utf8',
    env: {...process.env, GODOT: fake},
  });
  let ran: string[] = [];
  try {
    ran = readFileSync(record, 'utf8').split('\n').filter(Boolean).sort();
  } catch {
    // nothing ran
  }
  return {status: r.status, out: r.stdout + r.stderr, ran};
}

describe('parallel GUT runner: explicit test list', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-gut-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('runs only the listed scripts and sums their results', () => {
    const r = run('-j', '2', '-t', A);
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([A]);
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 0');
  });

  it('exits 1 and prints the failure when a listed script fails', () => {
    const r = run('-t', `${A},${B}`);
    expect(r.status).toBe(1);
    expect(r.ran).toEqual([B, A].sort());
    expect(r.out).toContain('Failed: test_x');
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 1');
  });

  it('refuses a path that is not a test script', () => {
    const r = run('-t', 'res://tests/test_does_not_exist.gd');
    expect(r.status).toBe(2);
    expect(r.out).toContain(
      'no test script at res://tests/test_does_not_exist.gd'
    );
    expect(r.ran).toEqual([]);
  });

  it('rejects an unknown option', () => {
    expect(run('--nope').status).toBe(2);
  });
});
