import {createApp} from './app';
import {positionAt, spawnEnemy} from './sim';
import {createAudio, soundFor} from './ui/audio';
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
  return crypto.getRandomValues(new Uint32Array(1))[0] || 1;
}

const app = createApp(slots.stage, pickSeed());
createHud(app, {
  top: slots.top,
  stage: slots.stage,
  panel: slots.panel,
  controls: slots.controls,
});

// Sound starts on the first tap and never before.
const audio = createAudio(
  () => new AudioContext(),
  () => performance.now()
);
// Touch only counts as a gesture on release, so unlock on pointerup, click
// and keydown, and keep retrying until the context is running.
for (const type of ['pointerup', 'click', 'keydown']) {
  window.addEventListener(type, () => audio.unlock());
}
app.subscribe(() => {
  for (const event of app.frameEvents) {
    const sound = soundFor(event);
    if (sound) audio.play(sound);
  }
});

// `?debug` exposes the app for the end-to-end and performance checks.
if (new URLSearchParams(location.search).has('debug')) {
  const hook = {
    app,
    /** Puts `count` robots on the route, for the performance check. */
    crowd(count: number): void {
      const types = ['skitter', 'hauler', 'smelter', 'overseer'] as const;
      for (let i = 0; i < count; i++) {
        const robot = spawnEnemy(
          app.game,
          types[i % types.length] ?? 'hauler',
          1
        );
        robot.speed = 0;
        robot.distance = (i / count) * app.game.route.total;
        const at = positionAt(app.game.route, robot.distance);
        robot.x = at.x;
        robot.y = at.y;
      }
    },
  };
  (window as unknown as {scrapline: typeof hook}).scrapline = hook;
}
