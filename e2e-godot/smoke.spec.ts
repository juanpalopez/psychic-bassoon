import {expect, test} from '@playwright/test';

// Proves the Godot web export starts: the shell loads the engine, the loading
// panel hides, the canvas has a WebGL2 context and nothing logs an error. It
// does not prove frames are drawn well; fps is a manual check on a phone.
test('the Godot export starts and renders a canvas', async ({page}) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });

  await page.goto('/index.html');
  await expect(page.locator('#status')).toBeHidden({timeout: 60_000});
  // set by main.gd once the scene is built, so the engine really ran
  await page.waitForFunction(
    () => (window as unknown as {scraplineReady?: boolean}).scraplineReady,
    undefined,
    {timeout: 60_000}
  );

  const state = await page.evaluate(() => {
    const canvas = document.querySelector<HTMLCanvasElement>('#canvas');
    return canvas
      ? {
          width: canvas.width,
          height: canvas.height,
          webgl2: canvas.getContext('webgl2') !== null,
        }
      : null;
  });
  expect(state).not.toBeNull();
  expect(state?.width).toBeGreaterThan(0);
  expect(state?.height).toBeGreaterThan(0);
  expect(state?.webgl2).toBe(true);
  expect(errors).toEqual([]);
});

test('an upright phone is asked to turn', async ({page}) => {
  await page.setViewportSize({width: 390, height: 780});
  await page.goto('/index.html');
  await expect(page.locator('#rotate')).toBeVisible();
});

test('the shell offers full screen and links an installable manifest', async ({
  page,
  request,
}) => {
  await page.goto('/index.html');
  const button = page.locator('#fullscreen');
  await expect(button).toBeVisible();
  const box = await button.boundingBox();
  expect(box?.width).toBeGreaterThanOrEqual(44);
  expect(box?.height).toBeGreaterThanOrEqual(44);

  const href = await page.locator('link[rel="manifest"]').getAttribute('href');
  expect(href).toBe('manifest.webmanifest');
  const response = await request.get('/manifest.webmanifest');
  expect(response.ok()).toBe(true);
  const manifest = await response.json();
  expect(manifest.display).toBe('fullscreen');
  expect(manifest.orientation).toBe('landscape');
});
