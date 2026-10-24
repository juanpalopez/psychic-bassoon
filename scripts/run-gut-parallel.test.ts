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
  order: string[];
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
    env: {
      ...process.env,
      GODOT: fake,
      // a file that does not exist: no recorded times unless a test writes its own
      GUT_TIMES_FILE: join(dir, 'times.json'),
    },
  });
  let ran: string[] = [];
  let order: string[] = [];
  try {
    order = readFileSync(record, 'utf8').split('\n').filter(Boolean);
    ran = [...order].sort();
  } catch {
    // nothing ran
  }
  return {status: r.status, out: r.stdout + r.stderr, ran, order};
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

describe('parallel GUT runner: recorded durations', () => {
  const C = 'res://tests/test_audio_flow.gd';
  const rel = (res: string) => `godot/${res.slice('res://'.length)}`;
  const times = () => join(dir, 'times.json');

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-gut-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('runs the longest recorded script first and batches the short ones', () => {
    writeFileSync(
      times(),
      JSON.stringify({[rel(A)]: 2, [rel(B)]: 30, [rel(C)]: 1})
    );
    const r = run('-j', '1', '-t', `${A},${B},${C}`);
    expect(r.status).toBe(1);
    expect(r.order).toEqual([B, `${A},${C}`]);
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 1');
  });

  it('runs scripts with no recorded time before the recorded ones', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 40}));
    const r = run('-j', '1', '-t', `${A},${C}`);
    expect(r.order).toEqual([C, A]);
  });

  it('reports a failing batch and exits 1', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 1, [rel(B)]: 1}));
    const r = run('-j', '2', '-t', `${A},${B}`);
    expect(r.order).toEqual([`${A},${B}`]);
    expect(r.status).toBe(1);
    expect(r.out).toContain('failure in');
    expect(r.out).toContain('Failed: test_x');
  });

  it('still runs everything when the times file is missing', () => {
    expect(run('-t', `${A},${B}`).ran).toEqual([B, A].sort());
  });

  it('still runs everything when the times file is garbage', () => {
    writeFileSync(times(), 'not json {{');
    expect(run('-t', `${A},${B}`).ran).toEqual([B, A].sort());
  });

  it('ignores times for scripts that no longer exist', () => {
    writeFileSync(times(), JSON.stringify({'godot/tests/gone.gd': 1}));
    const r = run('-t', A);
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([A]);
  });

  it('--write-times runs one script per process and merges the times', () => {
    writeFileSync(
      times(),
      JSON.stringify({[rel(A)]: 1, 'godot/tests/gone.gd': 9, [rel(C)]: 7})
    );
    const r = run('--write-times', '-t', A);
    expect(r.status).toBe(0);
    expect(r.order).toEqual([A]);
    const written = JSON.parse(readFileSync(times(), 'utf8'));
    expect(Object.keys(written).sort()).toEqual([rel(A), rel(C)].sort());
    expect(written[rel(C)]).toBe(7);
    expect(typeof written[rel(A)]).toBe('number');
  });

  it('--write-times leaves the file alone when a script fails', () => {
    writeFileSync(times(), JSON.stringify({[rel(B)]: 1}));
    const before = readFileSync(times(), 'utf8');
    expect(run('--write-times', '-t', B).status).toBe(1);
    expect(readFileSync(times(), 'utf8')).toBe(before);
  });
});
