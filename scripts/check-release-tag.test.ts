import {spawnSync} from 'node:child_process';
import {describe, expect, it} from 'vitest';

function check(tag: string): number | null {
  return spawnSync('bash', ['scripts/check-release-tag.sh', tag], {
    encoding: 'utf8',
  }).status;
}

describe('release tag check', () => {
  it.each([
    'v0.0.1',
    'v1.2.3',
    'v10.20.30',
    'v1.2.3-rc.1',
    'v0.0.1-test.1',
    'v1.2.3-0',
    'v1.2.3-1a',
    'v1.2.3-alpha-1',
  ])('accepts %s', tag => {
    expect(check(tag)).toBe(0);
  });

  it.each([
    'v01.2.3',
    'v1.02.3',
    'v1.2.03',
    'v1.2',
    'v1.2.3.4',
    'v1.2.3foo',
    'v1.2.3+meta',
    'v1.2.3-',
    'v1.2.3-.',
    'v1.2.3-rc..1',
    'v1.2.3-01',
    'v1.2.3-rc.01',
    'V1.2.3',
    '1.2.3',
    '',
  ])('rejects %j', tag => {
    expect(check(tag)).not.toBe(0);
  });

  it('rejects a missing argument', () => {
    const result = spawnSync('bash', ['scripts/check-release-tag.sh'], {
      encoding: 'utf8',
    });
    expect(result.status).not.toBe(0);
  });
});
