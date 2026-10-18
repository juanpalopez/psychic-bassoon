import {spawnSync} from 'node:child_process';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterAll, describe, expect, it} from 'vitest';

const dir = mkdtempSync(join(tmpdir(), 'run-godot-checked-'));
afterAll(() => rmSync(dir, {recursive: true, force: true}));

// Runs a stand-in for a Godot command (a bash snippet) through the checker.
function run(snippet: string, limit = '5'): number | null {
  return spawnSync(
    'bash',
    [
      'scripts/run-godot-checked.sh',
      limit,
      join(dir, 'run.log'),
      '--',
      'bash',
      '-c',
      snippet,
    ],
    {encoding: 'utf8'}
  ).status;
}

describe('run-godot-checked', () => {
  it('passes a clean run that only prints warnings and text', () => {
    expect(
      run('echo "Godot Engine v4.7.2"; echo "WARNING: something minor"')
    ).toBe(0);
  });

  it.each([
    [
      'an engine error',
      'echo "ERROR: Failed loading resource: res://nope.tres."',
    ],
    ['a script error', 'echo "SCRIPT ERROR: Parse Error: bad"'],
    ['a shader error', 'echo "SHADER ERROR: Unexpected token"'],
    ['a crash message on stderr', 'echo "ERROR: boom" >&2'],
    ['a non-zero exit', 'echo fine; exit 3'],
  ])('fails on %s', (_name, snippet) => {
    expect(run(snippet)).toBe(1);
  });

  it('fails when the command runs out of time', () => {
    expect(run('sleep 5', '1')).toBe(1);
  });

  it('does not mistake an error word inside a line for an engine error', () => {
    expect(run('echo "loaded 3 files, 0 ERROR: none"')).toBe(0);
  });

  it('refuses a call without the separator', () => {
    const status = spawnSync(
      'bash',
      ['scripts/run-godot-checked.sh', '5', 'x.log', 'true'],
      {
        encoding: 'utf8',
      }
    ).status;
    expect(status).toBe(2);
  });
});
