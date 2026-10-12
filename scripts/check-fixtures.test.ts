import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let dir: string;
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'fixtures-'));
});
afterEach(() => rmSync(dir, {recursive: true, force: true}));

function sha(text: string) {
  return createHash('sha256').update(text).digest('hex');
}

function check(target: string | undefined = dir) {
  const args = ['scripts/check-fixtures.mjs'];
  if (target) args.push(target);
  const r = spawnSync('node', args, {encoding: 'utf8'});
  return {status: r.status, output: r.stdout + r.stderr};
}

function seed(files: Record<string, string>, sums?: string) {
  for (const [name, text] of Object.entries(files)) {
    writeFileSync(join(dir, name), text);
  }
  const list =
    sums ??
    Object.entries(files)
      .map(([name, text]) => `${sha(text)}  ${name}\n`)
      .join('');
  writeFileSync(join(dir, 'SHA256SUMS'), list);
}

describe('check-fixtures script', () => {
  it('passes when every listed file matches', () => {
    seed({'a.json': '{"a":1}', 'b.json': '[1,2]'});
    expect(check().status).toBe(0);
  });

  it('fails when a listed file changed', () => {
    seed({'a.json': '{"a":1}'});
    writeFileSync(join(dir, 'a.json'), '{"a":2}');
    const r = check();
    expect(r.status).toBe(1);
    expect(r.output).toContain('a.json changed');
  });

  it('fails when a listed file is missing', () => {
    seed({}, `${sha('x')}  gone.json\n`);
    const r = check();
    expect(r.status).toBe(1);
    expect(r.output).toContain('missing');
  });

  it('fails when a JSON file is not listed', () => {
    seed({'a.json': '{}'});
    writeFileSync(join(dir, 'extra.json'), '{}');
    const r = check();
    expect(r.status).toBe(1);
    expect(r.output).toContain('extra.json is not listed');
  });

  it('fails on a malformed list', () => {
    seed({}, 'not a hash line\n');
    const r = check();
    expect(r.status).toBe(1);
    expect(r.output).toContain('malformed');
  });

  it('fails when the list is missing', () => {
    writeFileSync(join(dir, 'a.json'), '{}');
    expect(check().status).toBe(1);
  });

  it('passes on the real frozen fixtures', () => {
    const r = check('fixtures');
    expect(r.output).toContain('3 files match');
    expect(r.status).toBe(0);
  });
});
