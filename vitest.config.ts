import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    environment: 'node',
    // TODO(#7): remove once the first sim test exists.
    passWithNoTests: true,
  },
});
