import {expect, test} from '@playwright/test';

interface Hook {
  app: {
    game: {credits: number; map: {tiles: string[][]}};
    submit(command: unknown): void;
    stats(): {calls: number; triangles: number};
  };
  crowd(count: number): void;
}

// Plan budgets: under 120 draw calls and about 150k triangles with 80 robots.
// Headless Chromium has no real GPU, so this checks what is drawn, not fps;
// the 60 fps check stays manual on a phone (ticket #27).
test('stays inside the draw-call and triangle budget with 80 robots', async ({
  page,
}) => {
  await page.goto('/?seed=42&debug');
  await page.getByRole('button', {name: 'Deploy'}).click();

  await page.evaluate(() => {
    const {app, crowd} = (window as unknown as {scrapline: Hook}).scrapline;
    app.game.credits = 100_000;
    const towers = ['welder', 'rivetMortar', 'quenchCoil', 'mainlineArc'];
    let built = 0;
    app.game.map.tiles.forEach((line, row) =>
      line.forEach((tile, col) => {
        if (tile !== 'plate') return;
        const id = built++;
        app.submit({type: 'build', tower: towers[id % 4], col, row});
        // two upgrades each: every tower ends at level 3
        app.submit({type: 'upgrade', towerId: id});
        app.submit({type: 'upgrade', towerId: id});
      })
    );
    crowd(80);
  });

  // let the sim apply the commands and the renderer draw a few frames
  await page.waitForTimeout(1500);
  const stats = await page.evaluate(() =>
    (window as unknown as {scrapline: Hook}).scrapline.app.stats()
  );
  console.log(`draw calls ${stats.calls}, triangles ${stats.triangles}`);
  expect(stats.calls).toBeGreaterThan(0);
  expect(stats.calls).toBeLessThan(120);
  expect(stats.triangles).toBeLessThan(150_000);
});
