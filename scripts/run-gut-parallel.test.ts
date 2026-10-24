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

/** Lines of a file the fake Godot appends to, or none when it never wrote one. */
function lines(path: string): string[] {
  try {
    return readFileSync(path, 'utf8').split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

/**
 * Runs the runner with a fake Godot that records the -gtest value it was given (and its HOME)
 * and prints a GUT summary: a failing one for a script whose path contains `fps`, a passing one
 * otherwise; it aborts (134, no summary) on `audio`. `env` steers the crashes of #504:
 * FAKE_IMPORT_CRASHES=n makes the first n imports segfault (139); FAKE_CRASH_ONCE=text makes the
 * first run whose list contains the text segfault and the next one pass.
 */
function run(
  args: string[],
  env: Record<string, string> = {}
): {
  status: number | null;
  out: string;
  ran: string[];
  order: string[];
  homes: string[];
} {
  const fake = join(dir, 'godot');
  const record = join(dir, 'ran.txt');
  const homes = join(dir, 'homes.txt');
  for (const f of [record, homes, join(dir, 'imports'), join(dir, 'crashed')]) {
    rmSync(f, {force: true});
  }
  writeFileSync(
    fake,
    [
      '#!/usr/bin/env bash',
      'for a in "$@"; do',
      '  case "$a" in -gtest=*) t="${a#-gtest=}" ;; esac',
      'done',
      'if [ -z "${t:-}" ]; then',
      `  echo x >> "${dir}/imports"`,
      `  [ "$(wc -l < "${dir}/imports")" -le "\${FAKE_IMPORT_CRASHES:-0}" ] && exit 139`,
      '  exit 0',
      'fi',
      `echo "$t" >> "${record}"`,
      `echo "$HOME" >> "${homes}"`,
      'if [ -n "${FAKE_CRASH_ONCE:-}" ] && [[ "$t" == *"$FAKE_CRASH_ONCE"* ]] \\',
      `  && [ ! -e "${dir}/crashed" ]; then`,
      `  touch "${dir}/crashed"; echo "Segmentation fault: 11"; exit 139`,
      'fi',
      'case "$t" in',
      '  *audio*) echo "Abort trap: 6"; exit 134 ;;',
      '  *fps*) echo "$t"; echo "Failing Tests  1"; echo "Failed: test_x"; echo "Failed: test_x" ;;',
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
      ...env,
    },
  });
  const order = lines(record);
  return {
    status: r.status,
    out: r.stdout + r.stderr,
    ran: [...order].sort(),
    order,
    homes: lines(homes),
  };
}

describe('parallel GUT runner: explicit test list', () => {
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-gut-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('runs only the listed scripts and sums their results', () => {
    const r = run(['-j', '2', '-t', A]);
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([A]);
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 0');
  });

  it('exits 1 and prints the failure when a listed script fails', () => {
    const r = run(['-t', `${A},${B}`]);
    expect(r.status).toBe(1);
    expect(r.ran).toEqual([B, A].sort());
    expect(r.out).toContain('Failed: test_x');
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 1');
  });

  it('refuses a path that is not a test script', () => {
    const r = run(['-t', 'res://tests/test_does_not_exist.gd']);
    expect(r.status).toBe(2);
    expect(r.out).toContain(
      'no test script at res://tests/test_does_not_exist.gd'
    );
    expect(r.ran).toEqual([]);
  });

  it('rejects an unknown option', () => {
    expect(run(['--nope']).status).toBe(2);
  });
});

describe('parallel GUT runner: recorded durations', () => {
  const C = 'res://tests/test_block_flow.gd';
  // the fake Godot crashes (exit 134, no summary) on a path containing "audio"
  const D = 'res://tests/test_audio_flow.gd';
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
    const r = run(['-j', '1', '-t', `${A},${B},${C}`]);
    expect(r.status).toBe(1);
    expect(r.order).toEqual([B, `${A},${C}`]);
    expect(r.out).toContain('Passing Tests 2');
    expect(r.out).toContain('Failing Tests 1');
  });

  it('runs scripts with no recorded time before the recorded ones', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 40}));
    const r = run(['-j', '1', '-t', `${A},${C}`]);
    expect(r.order).toEqual([C, A]);
  });

  it('reports a failing batch and exits 1', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 1, [rel(B)]: 1}));
    const r = run(['-j', '2', '-t', `${A},${B}`]);
    expect(r.order).toEqual([`${A},${B}`]);
    expect(r.status).toBe(1);
    expect(r.out).toContain('failure in');
    expect(r.out).toContain('Failed: test_x');
  });

  it('names the failing script of a batch once', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 1, [rel(B)]: 1}));
    const r = run(['-t', `${A},${B}`]);
    expect(r.out).toContain(`failure in`);
    expect(r.out).toContain(B);
    expect(r.out.split('Failed: test_x').length - 1).toBe(1);
  });

  it('fails when Godot crashes, even with no summary', () => {
    writeFileSync(times(), JSON.stringify({[rel(A)]: 1, [rel(D)]: 1}));
    const r = run(['-t', `${A},${D}`]);
    expect(r.status).toBe(1);
    expect(r.out).toContain('godot exit code 134');
  });

  it('still runs everything when the times file is missing', () => {
    expect(run(['-t', `${A},${B}`]).ran).toEqual([B, A].sort());
  });

  it('still runs everything when the times file is garbage', () => {
    writeFileSync(times(), 'not json {{');
    expect(run(['-t', `${A},${B}`]).ran).toEqual([B, A].sort());
  });

  it('ignores times for scripts that no longer exist', () => {
    writeFileSync(times(), JSON.stringify({'godot/tests/gone.gd': 1}));
    const r = run(['-t', A]);
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([A]);
  });

  it('--write-times runs one script per process and merges the times', () => {
    writeFileSync(
      times(),
      JSON.stringify({[rel(A)]: 1, 'godot/tests/gone.gd': 9, [rel(C)]: 7})
    );
    const r = run(['--write-times', '-t', A]);
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
    expect(run(['--write-times', '-t', B]).status).toBe(1);
    expect(readFileSync(times(), 'utf8')).toBe(before);
  });
});

describe('parallel GUT runner: shards', () => {
  const T = [
    'res://tests/render/test_board.gd',
    'res://tests/render/test_camera_rig.gd',
    'res://tests/render/test_camera_yaw.gd',
    'res://tests/render/test_cell_highlight.gd',
    'res://tests/render/test_board_space.gd',
  ];
  const rel = (res: string) => `godot/${res.slice('res://'.length)}`;
  const times = () => join(dir, 'times.json');
  const list = T.join(',');
  const one = T[0] as string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-gut-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('deals the longest scripts onto the least-loaded shard', () => {
    // 50, 40, 30, 20, 10 seconds: shard 0 gets 50 + 20 + 10, shard 1 gets 40 + 30
    writeFileSync(
      times(),
      JSON.stringify(Object.fromEntries(T.map((p, i) => [rel(p), 50 - 10 * i])))
    );
    const s0 = run(['-j', '1', '--shard', '0/2', '-t', list]);
    const s1 = run(['-j', '1', '--shard', '1/2', '-t', list]);
    expect(s0.status).toBe(0);
    expect(s0.order).toEqual([T[0], T[3], T[4]]);
    expect(s1.order).toEqual([T[1], T[2]]);
    expect(s0.out).toContain('shard 0 of 2: 3 scripts');
  });

  it('gives every script to exactly one shard, the same way each time', () => {
    const first = [0, 1, 2].map(
      i => run(['--shard', `${i}/3`, '-t', list]).ran
    );
    const again = [0, 1, 2].map(
      i => run(['--shard', `${i}/3`, '-t', list]).ran
    );
    expect(again).toEqual(first);
    expect(first.flat().sort()).toEqual([...T].sort());
  });

  it('weighs a script with no recorded time at 20 seconds', () => {
    writeFileSync(times(), JSON.stringify({[rel(one)]: 25}));
    // T[0] weighs 25 and goes to shard 0; the two unknown scripts (20 each) both fit shard 1
    // before it reaches 25
    const s0 = run(['--shard', '0/2', '-t', T.slice(0, 3).join(',')]);
    expect(s0.ran).toEqual([T[0]]);
  });

  it('an empty shard exits 0 without running anything', () => {
    const r = run(['--shard', '1/2', '-t', one]);
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([]);
    expect(r.out).toContain('nothing in this shard');
  });

  it('a failing script in a shard fails that shard', () => {
    const r = run(['--shard', '0/1', '-t', 'res://tests/ui/test_fps_text.gd']);
    expect(r.status).toBe(1);
  });

  it('rejects a malformed shard and --write-times with a shard', () => {
    expect(run(['--shard', '2/2', '-t', one]).status).toBe(2);
    expect(run(['--shard', 'x/2', '-t', one]).status).toBe(2);
    expect(run(['--shard', '0', '-t', one]).status).toBe(2);
    expect(run(['--shard', '0/2', '--write-times', '-t', one]).status).toBe(2);
  });
});

describe('parallel GUT runner: crashes (#504)', () => {
  const C = 'res://tests/test_block_flow.gd';

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'pkd-gut-'));
  });
  afterEach(() => {
    rmSync(dir, {recursive: true, force: true});
  });

  it('runs a script that crashed once again, passes, and reports the crash', () => {
    const r = run(['-t', `${A},${C}`], {FAKE_CRASH_ONCE: 'block_flow'});
    expect(r.status).toBe(0);
    expect(r.ran).toEqual([A, C, C].sort());
    expect(r.out).toContain(`CRASH: godot exit code 139 running ${C}`);
    expect(r.out).toContain('crashes: 1');
    expect(r.out).toContain('Passing Tests 4');
  });

  it('fails the run when a script crashes on its second run too', () => {
    const D = 'res://tests/test_audio_flow.gd';
    const r = run(['-t', `${A},${D}`]);
    expect(r.status).toBe(1);
    expect(r.ran).toEqual([A, D, D].sort());
    expect(r.out).toContain('CRASH: godot exit code 134');
    expect(r.out).toContain('godot exit code 134)');
  });

  it('never runs a failing test again', () => {
    const r = run(['-t', B]);
    expect(r.status).toBe(1);
    expect(r.ran).toEqual([B]);
    expect(r.out).not.toContain('CRASH');
  });

  it('tries a crashed import once more before the tests', () => {
    const r = run(['-t', A], {FAKE_IMPORT_CRASHES: '1'});
    expect(r.status).toBe(0);
    expect(r.out).toContain('godot --import exited 139 (attempt 1 of 2)');
    expect(r.ran).toEqual([A]);
  });

  it('stops before the tests when the import crashes twice', () => {
    const r = run(['-t', A], {FAKE_IMPORT_CRASHES: '2'});
    expect(r.status).toBe(2);
    expect(r.out).toContain('the import failed twice');
    expect(r.ran).toEqual([]);
  });

  it('gives each run its own HOME, so user:// is not shared', () => {
    const r = run(['-j', '2', '-t', `${A},${B},${C}`]);
    expect(r.homes).toHaveLength(3);
    expect(new Set(r.homes).size).toBe(3);
    for (const home of r.homes) {
      expect(home).toMatch(/gut-par\.[^/]+\/home_\d+$/);
    }
  });

  it('rejects a worker count that is not a number', () => {
    expect(run(['-t', A], {GUT_JOBS: 'many'}).status).toBe(2);
    expect(run(['-j', 'x', '-t', A]).status).toBe(2);
  });
});
