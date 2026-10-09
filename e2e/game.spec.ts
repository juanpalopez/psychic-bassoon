import {expect, test} from '@playwright/test';

// Plays the first minute through the real UI: deploy, tap a plot, build,
// launch a wave, and see foes walk. Seed 42 keeps the map fixed.
test('builds a tower and survives the start of a wave', async ({page}) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });

  await page.goto('/?seed=42&debug');
  await expect(page.locator('.overlay .card h1')).toContainText('Scrap');
  await page.getByRole('button', {name: 'Deploy'}).click();
  await expect(page.locator('.overlay')).toBeHidden();

  // Tap across the board until a plot opens the build sheet.
  const stage = await page.locator('#stage').boundingBox();
  if (!stage) throw new Error('no stage');
  let opened = false;
  for (let fy = 0.35; fy < 0.9 && !opened; fy += 0.07) {
    for (let fx = 0.15; fx < 0.9 && !opened; fx += 0.1) {
      await page.mouse.click(
        stage.x + stage.width * fx,
        stage.y + stage.height * fy
      );
      opened = (await page.locator('#panel .build').count()) > 0;
    }
  }
  expect(opened).toBe(true);

  const gold = page.locator('.stat.gold b');
  await expect(gold).toHaveText('180');
  await page.locator('#panel .bcard').first().click();
  await expect(gold).toHaveText('130');
  await expect(page.locator('#panel .info h3')).toContainText('Ballista');

  await page.getByRole('button', {name: /Launch wave 1/}).click();
  await expect(page.locator('.stat').nth(2).locator('b')).toHaveText('1');
  await page.getByRole('button', {name: 'Game speed'}).click();
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (
            window as unknown as {
              scrapline: {app: {game: {enemies: unknown[]}}};
            }
          ).scrapline.app.game.enemies.length
      )
    )
    .toBeGreaterThan(0);
  expect(errors).toEqual([]);
});

test('offers the next wave after a clear and can auto-start the rest', async ({
  page,
}) => {
  await page.goto('/?seed=42&debug');
  await page.getByRole('button', {name: 'Deploy'}).click();
  await page.getByRole('button', {name: /Launch wave 1/}).click();
  await expect(page.locator('.stat').nth(2).locator('b')).toHaveText('1');
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (
            window as unknown as {
              scrapline: {app: {game: {spawners: unknown[]}}};
            }
          ).scrapline.app.game.spawners.length
      )
    )
    .toBeGreaterThan(0);

  // clear the wave through the game itself
  await page.evaluate(() => {
    const {app} = (
      window as unknown as {
        scrapline: {
          app: {game: {spawners: unknown[]; enemies: {alive: boolean}[]}};
        };
      }
    ).scrapline;
    app.game.spawners = [];
    for (const enemy of app.game.enemies) enemy.alive = false;
  });
  const popup = page.locator('.next-wave');
  await expect(popup).toBeVisible();
  await expect(popup.getByRole('button')).toHaveText('Start wave 2');

  // turning auto-start on launches wave 2 by itself and hides the popup
  await popup.getByLabel('Auto-start next waves').check();
  await expect(popup).toBeHidden();
  await expect(page.locator('.stat').nth(2).locator('b')).toHaveText('2');
});

test('loads the real GLB models, not the primitive fallbacks', async ({
  page,
}) => {
  await page.goto('/?seed=42&debug');
  // the app starts after the models have loaded
  await page.waitForFunction(
    () => (window as unknown as {scrapline?: unknown}).scrapline !== undefined
  );
  const sources = await page.evaluate(
    () =>
      (window as unknown as {scrapline: {modelSources: Record<string, string>}})
        .scrapline.modelSources
  );
  expect(sources.ironclad).toBe('glb');
  expect(Object.values(sources).filter(s => s === 'primitive')).toEqual([]);
});
