import {expect, test} from '@playwright/test';

// Plays the first minute through the real UI: deploy, tap a plate, build,
// launch a wave, and see robots walk. Seed 42 keeps the map fixed.
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

  // Tap across the board until a plate opens the build sheet.
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

  const credits = page.locator('.stat.credits b');
  await expect(credits).toHaveText('180');
  await page.locator('#panel .bcard').first().click();
  await expect(credits).toHaveText('130');
  await expect(page.locator('#panel .info h3')).toContainText('Welder');

  await page.getByRole('button', {name: /Launch wave 1/}).click();
  await expect(page.locator('.stat').nth(2).locator('b')).toHaveText('1');
  await page.getByRole('button', {name: 'Game speed'}).click();
  await expect
    .poll(() =>
      page.evaluate(
        () =>
          (window as unknown as {scrapline: {game: {enemies: unknown[]}}})
            .scrapline.game.enemies.length
      )
    )
    .toBeGreaterThan(0);
  expect(errors).toEqual([]);
});
