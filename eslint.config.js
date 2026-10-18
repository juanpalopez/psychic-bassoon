import js from '@eslint/js';
import globals from 'globals';
import prettier from 'eslint-config-prettier';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist', 'node_modules', 'build', 'godot', '.claude'],
  },
  js.configs.recommended,
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,
  {
    files: ['**/*.{ts,js,mjs}'],
    languageOptions: {
      globals: {...globals.browser, ...globals.node},
    },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
    },
  },
  {
    // Google TypeScript Style Guide: naming, exports and control flow.
    // Formatting is Prettier's job (see .prettierrc.json).
    files: ['**/*.{ts,js,mjs}'],
    rules: {
      '@typescript-eslint/naming-convention': [
        'error',
        {selector: 'default', format: ['camelCase']},
        {
          selector: 'variable',
          format: ['camelCase', 'UPPER_CASE'],
          leadingUnderscore: 'allow',
        },
        {
          selector: 'parameter',
          format: ['camelCase'],
          leadingUnderscore: 'allow',
        },
        {selector: 'typeLike', format: ['PascalCase']},
        {selector: 'enumMember', format: ['UPPER_CASE']},
        {
          selector: [
            'objectLiteralProperty',
            'typeProperty',
            'objectLiteralMethod',
          ],
          format: null,
        },
        {selector: 'import', format: null},
      ],
      curly: ['error', 'multi-line'],
      eqeqeq: ['error', 'always'],
      'no-var': 'error',
      'prefer-const': 'error',
    },
  },
  {
    // Named exports only. Tool config files need a default export.
    files: ['scripts/**/*.mjs', 'scripts/**/*.ts'],
    rules: {
      'no-restricted-exports': [
        'error',
        {
          restrictDefaultExports: {
            direct: true,
            named: true,
            defaultFrom: true,
            namedFrom: true,
            namespaceFrom: true,
          },
        },
      ],
    },
  },
  prettier
);
