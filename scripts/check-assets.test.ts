import {spawnSync} from 'node:child_process';
import {randomFillSync} from 'node:crypto';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';

let root: string;
let assets: string;
let credits: string;

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), 'check-assets-'));
  assets = join(root, 'assets');
  credits = join(root, 'CREDITS.md');
  mkdirSync(join(assets, 'models', 'kit'), {recursive: true});
});

afterEach(() => {
  rmSync(root, {recursive: true, force: true});
});

function run() {
  const result = spawnSync(
    'node',
    ['scripts/check-assets.mjs', assets, credits],
    {encoding: 'utf8'}
  );
  return {status: result.status, output: result.stdout + result.stderr};
}

describe('check-assets script', () => {
  it('passes when every file is credited and the size is small', () => {
    writeFileSync(join(assets, 'models', 'kit', 'a.glb'), 'glb');
    writeFileSync(credits, '| `models/kit/a.glb` | Kenney | CC0 | none |\n');
    expect(run().status).toBe(0);
  });

  it('fails for a file missing from the credits', () => {
    writeFileSync(join(assets, 'models', 'kit', 'a.glb'), 'glb');
    writeFileSync(credits, '# Credits\n');
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('models/kit/a.glb is not recorded');
  });

  it('fails for a credit that names a file that is gone', () => {
    writeFileSync(credits, '| `models/kit/gone.glb` | Kenney | CC0 | none |\n');
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('lists models/kit/gone.glb');
  });

  it('ignores .gitkeep', () => {
    writeFileSync(join(assets, '.gitkeep'), '');
    writeFileSync(credits, '# Credits\n');
    expect(run().status).toBe(0);
  });

  it('fails over the 6 MB budget', () => {
    writeFileSync(
      join(assets, 'models', 'kit', 'big.glb'),
      randomFillSync(Buffer.alloc(6_500_000))
    );
    writeFileSync(credits, '| `models/kit/big.glb` | Kenney | CC0 | none |\n');
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('Asset size budget exceeded');
  });

  it('fails when the credits file is missing', () => {
    expect(run().status).toBe(1);
  });

  it('ignores .DS_Store', () => {
    writeFileSync(join(assets, 'models', '.DS_Store'), 'junk');
    writeFileSync(credits, '# Credits\n');
    expect(run().status).toBe(0);
  });

  it('rejects a symlink, which could hide size', () => {
    writeFileSync(
      join(root, 'big.bin'),
      randomFillSync(Buffer.alloc(7_000_000))
    );
    symlinkSync(
      join(root, 'big.bin'),
      join(assets, 'models', 'kit', 'big.glb')
    );
    writeFileSync(credits, '| `models/kit/big.glb` | Kenney | CC0 | none |\n');
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('not a regular file');
  });

  it('fails a credit that does not name the CC0 licence', () => {
    writeFileSync(join(assets, 'models', 'kit', 'a.glb'), 'glb');
    writeFileSync(
      credits,
      '| `models/kit/a.glb` | Someone | CC BY 4.0 | none |\n'
    );
    const result = run();
    expect(result.status).toBe(1);
    expect(result.output).toContain('does not say CC0');
  });
});
