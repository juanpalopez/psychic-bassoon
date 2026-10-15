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

  await page.goto('/index.html?tour=0');
  await expect(page.locator('#status')).toBeHidden({timeout: 60_000});
  // set by main.gd once the scene is built, so the engine really ran
  await page.waitForFunction(
    () => (window as unknown as {gameReady?: boolean}).gameReady,
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
  await page.goto('/index.html?tour=0');
  await expect(page.locator('#rotate')).toBeVisible();
});

test('the shell offers full screen and links a manifest', async ({
  page,
  request,
}) => {
  await page.goto('/index.html?tour=0');
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

test('full screen can be entered and left', async ({page}) => {
  await page.goto('/index.html?tour=0');
  const button = page.locator('#fullscreen');
  await button.click();
  await expect
    .poll(() => page.evaluate(() => document.fullscreenElement !== null))
    .toBe(true);
  await expect(button).toHaveText('Exit full screen');
  await button.click();
  await expect
    .poll(() => page.evaluate(() => document.fullscreenElement === null))
    .toBe(true);
});

test('without the Fullscreen API the button shows the install hint', async ({
  page,
}) => {
  await page.addInitScript(() => {
    Object.defineProperty(Element.prototype, 'requestFullscreen', {
      value: undefined,
    });
    Object.defineProperty(Element.prototype, 'webkitRequestFullscreen', {
      value: undefined,
    });
  });
  await page.goto('/index.html?tour=0');
  await expect(page.locator('#installHint')).toBeHidden();
  await page.locator('#fullscreen').click();
  await expect(page.locator('#installHint')).toBeVisible();
});

test('an installed app shows no full screen button', async ({page}) => {
  await page.addInitScript(() => {
    const original = window.matchMedia.bind(window);
    window.matchMedia = (query: string) =>
      query.includes('display-mode')
        ? ({...original(query), matches: true} as MediaQueryList)
        : original(query);
  });
  await page.goto('/index.html?tour=0');
  await expect(page.locator('#fullscreen')).toBeHidden();
});

test('the old /godot/ address sends visitors to the root', async ({page}) => {
  await page.goto('/godot/');
  await page.waitForURL(url => !url.pathname.includes('/godot'));
  expect(new URL(page.url()).pathname).toBe('/');
});

// Safari numbers its touches from wherever it left off, so the first finger can be
// touch id 7 and not 0. The board once read that as a second finger and ignored
// every tap (iOS: the HUD worked, sockets did not). Unit tests cannot see browser
// touch numbering, so this taps a socket with id 7 in an iPhone-sized viewport.
test('a tap with a touch id other than 0 selects a socket', async ({
  browser,
  baseURL,
}) => {
  const context = await browser.newContext({
    viewport: {width: 844, height: 390},
    deviceScaleFactor: 3,
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  await page.goto(`${baseURL}/index.html?tour=0`);
  await page.waitForFunction(
    () => (window as unknown as {gameReady?: boolean}).gameReady,
    undefined,
    {timeout: 60_000}
  );
  await page.waitForTimeout(1_000);
  const cdp = await context.newCDPSession(page);
  // a socket of the first map, at this viewport
  for (const type of ['touchStart', 'touchEnd'] as const) {
    await cdp.send('Input.dispatchTouchEvent', {
      type,
      touchPoints: type === 'touchStart' ? [{x: 422, y: 213, id: 7}] : [],
    });
    await page.waitForTimeout(80);
  }
  await page.waitForFunction(
    () =>
      (window as unknown as {gameSelected?: string}).gameSelected !== undefined,
    undefined,
    {timeout: 10_000}
  );
  const selected = await page.evaluate(
    () => (window as unknown as {gameSelected?: string}).gameSelected
  );
  expect(selected).not.toBe('-1,-1');
  await context.close();
});

// The first-visit intro wave opens by itself on a fresh browser, and stays closed once it was seen.
test('the tour opens on a first visit and not after it was seen', async ({
  browser,
}) => {
  // the game is loaded twice here, which needs more than the default 30 s on a slow runner
  test.setTimeout(120_000);
  const open = async (seen: boolean) => {
    const context = await browser.newContext({
      viewport: {width: 844, height: 390},
    });
    const page = await context.newPage();
    if (seen) {
      await page.addInitScript(() =>
        localStorage.setItem('papercraft_tour_seen', '1')
      );
    }
    await page.goto('/index.html');
    await page.waitForFunction(
      () => (window as unknown as {gameReady?: boolean}).gameReady,
      undefined,
      {timeout: 60_000}
    );
    const tourOpen = await page.evaluate(
      () =>
        (window as unknown as {gameTourOpen?: boolean}).gameTourOpen === true
    );
    await context.close();
    return tourOpen;
  };
  expect(await open(false)).toBe(true);
  expect(await open(true)).toBe(false);
});

// The phone check: ?stress=80 keeps about 80 foes walking and ?fps shows the overlay.
test('the stress parameter keeps about 80 foes on the board', async ({
  page,
}) => {
  await page.goto('/index.html?stress=80&fps');
  await page.waitForFunction(
    () => (window as unknown as {gameReady?: boolean}).gameReady,
    undefined,
    {timeout: 60_000}
  );
  // the overlay reports the foe count to the page a few times a second
  await page.waitForFunction(
    () => ((window as unknown as {gameFoes?: number}).gameFoes ?? 0) >= 70,
    undefined,
    {timeout: 30_000}
  );
  const tourOpen = await page.evaluate(
    () => (window as unknown as {gameTourOpen?: boolean}).gameTourOpen === true
  );
  expect(tourOpen).toBe(false);
});
