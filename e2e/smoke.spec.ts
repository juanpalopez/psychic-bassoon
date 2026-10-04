import {expect, test} from '@playwright/test';

// Proves the canvas mounts, gets a WebGL2 context and is sized to the viewport
// without console errors. It does not prove that frames are drawn.
test('mounts a WebGL canvas sized to the viewport', async ({page}) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });

  await page.goto('/');

  const canvas = page.locator('#stage canvas');
  await expect(canvas).toBeVisible();

  const state = await page.evaluate(() => {
    const canvasEl = document.querySelector<HTMLCanvasElement>('#stage canvas');
    const container = document.getElementById('stage');
    if (!canvasEl || !container) return null;
    return {
      width: canvasEl.width,
      height: canvasEl.height,
      expectedWidth: Math.round(
        container.clientWidth * Math.min(window.devicePixelRatio, 2)
      ),
      hasWebgl2: canvasEl.getContext('webgl2') !== null,
    };
  });

  expect(state).not.toBeNull();
  expect(state?.hasWebgl2).toBe(true);
  expect(state?.width).toBe(state?.expectedWidth);
  expect(state?.height).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});
