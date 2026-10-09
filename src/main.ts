import {createApp} from './app';
import {glbSceneLoader, loadModelLibrary} from './render/models/library';
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

/** `?seed=123` replays a map; otherwise every visit is a new road. */
function pickSeed(): number {
  const fromUrl = Number(new URLSearchParams(location.search).get('seed'));
  if (Number.isSafeInteger(fromUrl) && fromUrl > 0) return fromUrl;
  return crypto.getRandomValues(new Uint32Array(1))[0] || 1;
}

// Models load first (a few small GLBs); any that fail fall back to primitives.
const models = await loadModelLibrary(
  glbSceneLoader(`${import.meta.env.BASE_URL}assets/models/`)
);
const app = createApp(slots.stage, pickSeed(), models);
createHud(app, {
  top: slots.top,
  stage: slots.stage,
  panel: slots.panel,
  controls: slots.controls,
});

// A phone held upright shows the 'turn your phone' prompt: pause behind it.
const upright = window.matchMedia(
  '(orientation: portrait) and (max-width: 700px)'
);
const pauseWhenUpright = (): void => {
  if (upright.matches) app.setPaused(true);
};
upright.addEventListener('change', pauseWhenUpright);

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
    /** Where each unit's model came from ('glb' or 'primitive'). */
    modelSources: models.sources,
    /**
     * Puts `count` foes on the route, for the performance check, in a mix like
     * a real wave: mostly Raiders and Scamps, a few Ironclads, a Warlord.
     */
    crowd(count: number): void {
      const mix = [
        'raider',
        'scamp',
        'raider',
        'ironclad',
        'raider',
        'scamp',
        'raider',
        'raider',
        'scamp',
        'warlord',
      ] as const;
      for (let i = 0; i < count; i++) {
        const foe = spawnEnemy(app.game, mix[i % mix.length] ?? 'raider', 1);
        foe.speed = 0;
        foe.distance = (i / count) * app.game.route.total;
        const at = positionAt(app.game.route, foe.distance);
        foe.x = at.x;
        foe.y = at.y;
      }
    },
  };
  (window as unknown as {scrapline: typeof hook}).scrapline = hook;
}
