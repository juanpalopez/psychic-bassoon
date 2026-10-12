import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
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

  it('fails on a JSON file in a subfolder or with another case', () => {
    seed({'a.json': '{}'});
    mkdirSync(join(dir, 'sub'));
    writeFileSync(join(dir, 'sub', 'b.json'), '{}');
    expect(check().status).toBe(1);
    rmSync(join(dir, 'sub'), {recursive: true});
    writeFileSync(join(dir, 'NEW.JSON'), '{}');
    expect(check().status).toBe(1);
  });

  // Pinned here so a change to a frozen fixture has to touch this test as well
  // as SHA256SUMS, and CI also rejects any diff under fixtures/ in a PR.
  it('lists exactly the three frozen fixtures with their hashes', () => {
    const sums = readFileSync('fixtures/SHA256SUMS', 'utf8');
    expect(sums).toBe(
      [
        '43f05c07263d91bc64e4761dca60dcdb2e4714ba121545c959a67b5c8cd8010b  prng.json',
        'ebec8a74c772eea8bf02576e74a668057e4a8854dffc7ace050f6b647b1cfcba  maps.json',
        '7625d599b0012a31d0fa07a1a55e0671d7ad31f0822a341a9b92c29f27aab202  routes.json',
        '',
      ].join('\n')
    );
  });

  it('passes on the real frozen fixtures', () => {
    const r = check('fixtures');
    expect(r.output).toContain('3 files match');
    expect(r.status).toBe(0);
  });
});
