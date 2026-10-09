import {readdirSync, readFileSync} from 'node:fs';
import {join} from 'node:path';
import {describe, expect, it} from 'vitest';

// A blind find-and-replace once turned `grid-template-columns` into
// `grid-templot-columns`: browsers drop unknown properties, so the layout
// broke and no check noticed. Property names must never contain game words.
describe('CSS property names', () => {
  const dir = 'src/ui';
  const sheets = readdirSync(dir).filter(f => f.endsWith('.css'));

  it.each(sheets)('%s has no property name containing a game word', sheet => {
    const css = readFileSync(join(dir, sheet), 'utf8');
    const bad = css
      .split('\n')
      .filter(line => /^\s+[a-z-]*(plot|road|foe|gold)[a-z-]*\s*:/.test(line));
    expect(bad).toEqual([]);
  });
});
