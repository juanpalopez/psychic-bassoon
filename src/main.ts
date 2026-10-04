import {createApp} from './app';

const container = document.getElementById('app');
if (!container) {
  throw new Error('Missing #app container');
}

/** `?seed=123` replays a map; otherwise every visit is a new factory. */
function pickSeed(): number {
  const fromUrl = Number(new URLSearchParams(location.search).get('seed'));
  if (Number.isSafeInteger(fromUrl) && fromUrl > 0) return fromUrl;
  return crypto.getRandomValues(new Uint32Array(1))[0] ?? 1;
}

const app = createApp(container, pickSeed());

// `?debug` exposes the app for the end-to-end and performance checks.
if (new URLSearchParams(location.search).has('debug')) {
  (window as unknown as {scrapline: typeof app}).scrapline = app;
}
