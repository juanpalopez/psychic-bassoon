import {ESLint} from 'eslint';
import {describe, expect, it} from 'vitest';

const eslint = new ESLint({overrideConfigFile: 'eslint.config.js'});

async function ruleIds(code: string): Promise<string[]> {
  const [result] = await eslint.lintText(code, {
    filePath: 'src/sim/probe.ts',
  });
  return (result?.messages ?? []).map(message => message.ruleId ?? 'parse');
}

describe('sim determinism lint rules', () => {
  const forbidden: [string, string][] = [
    ['Date()', 'export const a = Date();\n'],
    ['new Date()', 'export const a = new Date();\n'],
    ['Date.now()', 'export const a = Date.now();\n'],
    ['globalThis.Date()', 'export const a = globalThis.Date();\n'],
    ['new globalThis.Date()', 'export const a = new globalThis.Date();\n'],
    ['Math.random()', 'export const a = Math.random();\n'],
    [
      'globalThis.Math.random()',
      'export const a = globalThis.Math.random();\n',
    ],
    [
      "globalThis['Date'].now()",
      "export const a = globalThis['Date'].now();\n",
    ],
    [
      'destructuring Date from globalThis',
      'const {Date: D} = globalThis;\nexport const a = D.now();\n',
    ],
    [
      'an alias of globalThis',
      'const g = globalThis;\nexport const a = g.Date.now();\n',
    ],
    ['dynamic import of three', "export const a = import('three');\n"],
    ['dynamic import of render', "export const a = import('../render/x');\n"],
    ['globalThis.document', 'export const a = globalThis.document;\n'],
  ];

  it.each(forbidden)('rejects %s', async (_name, code) => {
    const ids = await ruleIds(code);
    expect(ids.length).toBeGreaterThan(0);
    expect(ids).not.toContain('parse');
  });

  const allowed: [string, string][] = [
    ['new Date(0), a fixed instant', 'export const a = new Date(0);\n'],
    ['structuredClone', 'export const a = structuredClone({b: 1});\n'],
  ];

  it.each(allowed)('allows %s', async (_name, code) => {
    expect(await ruleIds(code)).toEqual([]);
  });
});
