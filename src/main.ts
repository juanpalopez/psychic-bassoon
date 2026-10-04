import {createApp} from './app';
import {createHud} from './ui/hud';

const slots = {
  top: document.getElementById('hud-top'),
  stage: document.getElementById('stage'),
  panel: document.getElementById('panel'),
  controls: document.getElementById('controls'),
};
if (!slots.top || !slots.stage || !slots.panel || !slots.controls) {
  throw new Error('Missing HUD containers in index.html');
}

/** `?seed=123` replays a map; otherwise every visit is a new factory. */
function pickSeed(): number {
  const fromUrl = Number(new URLSearchParams(location.search).get('seed'));
  if (Number.isSafeInteger(fromUrl) && fromUrl > 0) return fromUrl;
  return crypto.getRandomValues(new Uint32Array(1))[0] ?? 1;
}

const app = createApp(slots.stage, pickSeed());
createHud(app, {
  top: slots.top,
  stage: slots.stage,
  panel: slots.panel,
  controls: slots.controls,
});

// `?debug` exposes the app for the end-to-end and performance checks.
if (new URLSearchParams(location.search).has('debug')) {
  (window as unknown as {scrapline: typeof app}).scrapline = app;
}
