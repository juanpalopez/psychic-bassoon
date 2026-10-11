import {defineConfig, devices} from '@playwright/test';

const PORT = 4174;

// Smoke test for the Godot web export in `build/web/` (built by the Godot job).
export default defineConfig({
  testDir: 'e2e-godot',
  expect: {timeout: 30_000},
  retries: 0,
  reporter: process.env.CI ? [['github']] : 'list',
  use: {baseURL: `http://127.0.0.1:${PORT}`},
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Pixel 7 landscape'],
        launchOptions: {
          args: [
            '--use-angle=swiftshader',
            '--enable-unsafe-swiftshader',
            '--ignore-gpu-blocklist',
          ],
        },
      },
    },
  ],
  webServer: {
    command: `node scripts/serve-static.mjs build/web ${PORT} 127.0.0.1`,
    url: `http://127.0.0.1:${PORT}/index.html`,
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
