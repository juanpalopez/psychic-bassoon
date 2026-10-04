import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';

const allowedInSim = new Set(['structuredClone']);
const domGlobals = Object.keys(globals.browser).filter(
  (name) => !(name in globals.es2021) && !allowedInSim.has(name),
);

export default tseslint.config(
  { ignores: ['dist', 'node_modules', 'playwright-report', 'test-results'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.{ts,js,mjs}'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
    },
  },
  {
    // The sim is pure, deterministic domain code. See CLAUDE.md, Architecture.
    files: ['src/sim/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['**/render', '**/render/**', '**/ui', '**/ui/**'],
              message: 'src/sim must not import from render or ui.',
            },
            {
              group: ['three', 'three/*'],
              message: 'src/sim must not import three.',
            },
          ],
        },
      ],
      'no-restricted-globals': [
        'error',
        ...domGlobals.map((name) => ({
          name,
          message: 'src/sim must not use the DOM or browser APIs.',
        })),
      ],
      'no-restricted-properties': [
        'error',
        {
          object: 'Math',
          property: 'random',
          message: 'Use the seeded PRNG in src/sim/rng.ts.',
        },
        {
          object: 'Date',
          property: 'now',
          message: 'The sim must not read the clock; time is ticks.',
        },
        ...domGlobals.map((name) => ({
          object: 'globalThis',
          property: name,
          message: 'src/sim must not use the DOM or browser APIs.',
        })),
      ],
      'no-restricted-syntax': [
        'error',
        {
          selector:
            "ImportExpression[source.value=/(^|\\/)(render|ui)(\\/|$)|^three(\\/|$)/]",
          message: 'src/sim must not import from render, ui or three.',
        },
        {
          selector: "ImportExpression:not([source.type='Literal'])",
          message: 'Dynamic import specifiers in src/sim must be string literals so the boundary rule can check them.',
        },
        {
          selector: "NewExpression[callee.name='Date'][arguments.length=0]",
          message: 'The sim must not read the clock; time is ticks.',
        },
      ],
    },
  },
);
