import type {TowerId} from '../content';
import type {App} from '../app';
import {loadBest, saveBest} from './best';
import {hudModel, toastFor} from './hud-model';
import type {BuildOption, HudModel, PanelModel} from './hud-model';
import {buildCommand, sellCommand, upgradeCommand} from './selection';
import './hud.css';

const TOAST_MS = 1800;
/** The DOM is refreshed at most this often; the 3D scene runs every frame. */
const REFRESH_MS = 100;
const SPEEDS = [1, 2, 3] as const;

/** CSS token for each tower's tint (see tokens.css). */
const TINT: Readonly<Record<TowerId, string>> = {
  welder: 'var(--welder)',
  rivetMortar: 'var(--rivet-mortar)',
  quenchCoil: 'var(--quench-coil)',
  mainlineArc: 'var(--mainline-arc)',
};

type Child = Node | string;

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className = '',
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.append(...children);
  return node;
}

function button(
  label: string,
  className: string,
  onClick: () => void,
  disabled = false
): HTMLButtonElement {
  const b = el('button', className, label);
  b.type = 'button';
  b.disabled = disabled;
  b.addEventListener('click', onClick);
  return b;
}

interface Slots {
  readonly top: HTMLElement;
  readonly stage: HTMLElement;
  readonly panel: HTMLElement;
  readonly controls: HTMLElement;
}

/** Builds the DOM overlay and keeps it in step with the app. */
export function createHud(app: App, slots: Slots): void {
  const {top, stage, panel, controls} = slots;

  // --- top bar
  const stat = (className: string, label: string) => {
    const value = el('b', '', '0');
    top.append(el('div', `stat ${className}`, el('span', '', label), value));
    return value;
  };
  const credits = stat('credits', 'Credits');
  const livesBox = top.appendChild(el('div', 'stat core'));
  const lives = el('b', '', '0');
  livesBox.append(el('span', '', 'Core'), lives);
  const wave = stat('', 'Wave');
  const bestValue = stat('', 'Best');

  // --- stage: toast and overlay
  const toast = stage.appendChild(el('div', 'toast off'));
  toast.setAttribute('role', 'status');
  toast.setAttribute('aria-live', 'polite');
  const overlay = stage.appendChild(el('div', 'overlay'));
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');

  // --- controls
  const pause = button('II', '', () => {
    app.setPaused(!app.paused);
    showPause();
  });
  pause.setAttribute('aria-label', 'Pause');
  const speedButton = button('1×', '', () => {
    const next = SPEEDS[(SPEEDS.indexOf(app.speed as 1) + 1) % SPEEDS.length];
    app.setSpeed(next ?? 1);
    speedButton.textContent = `${next ?? 1}×`;
  });
  speedButton.setAttribute('aria-label', 'Game speed');
  const launch = button('Launch wave 1', 'primary', () =>
    app.submit({type: 'launchWave'})
  );
  const autoButton = button('Auto', 'toggle', () => setAuto(!app.autoStart));
  autoButton.setAttribute('aria-label', 'Auto-start next waves');
  controls.append(pause, speedButton, autoButton, launch);

  // --- next-wave popup, shown when a wave is cleared
  const nextTitle = el('div', 'eyebrow');
  const nextButton = button('Start next wave', 'primary', () => {
    app.submit({type: 'launchWave'});
    hideNext();
  });
  const autoBox = el('input');
  autoBox.type = 'checkbox';
  autoBox.id = 'auto-start';
  autoBox.addEventListener('change', () => setAuto(autoBox.checked));
  const autoLabel = el('label', 'auto-row', autoBox, 'Auto-start next waves');
  autoLabel.htmlFor = 'auto-start';
  const next = stage.appendChild(
    el('div', 'next-wave', nextTitle, nextButton, autoLabel)
  );
  next.hidden = true;
  const hideNext = (): void => {
    next.hidden = true;
  };
  const setAuto = (on: boolean): void => {
    app.setAutoStart(on);
    autoBox.checked = on;
    autoButton.setAttribute('aria-pressed', String(on));
    autoButton.classList.toggle('on', on);
    if (on) hideNext();
  };
  setAuto(app.autoStart);

  let best = loadBest(localStorage);
  let toastTimer: number | undefined;
  const say = (message: string): void => {
    toast.textContent = message;
    toast.classList.remove('off');
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => toast.classList.add('off'), TOAST_MS);
  };

  // --- overlays
  type Mode = 'start' | 'pause' | 'over' | 'none';
  let mode: Mode = 'none';
  const show = (next: Mode, content?: Node): void => {
    mode = next;
    overlay.hidden = next === 'none';
    overlay.replaceChildren(...(content ? [content] : []));
  };
  const newMap = (): void => {
    app.restart(crypto.getRandomValues(new Uint32Array(1))[0] || 1);
    hideNext();
    app.setPaused(false);
    show('none');
  };
  const showStart = (): void =>
    show(
      'start',
      el(
        'div',
        'card',
        el('div', 'eyebrow', 'Foundry Nine · night shift'),
        el('h1', '', 'Scrap', el('em', '', 'line')),
        el(
          'p',
          '',
          'FOREMAN is sending its workforce down the scraplines to tear out your Core. Every map is a new factory.'
        ),
        el(
          'ul',
          '',
          el('li', '', 'Tap a plate beside the belt to build a tower.'),
          el('li', '', 'Tap a tower to upgrade it (3 levels) or sell it.'),
          el(
            'li',
            '',
            'Hold the Core as long as you can. An Overseer arrives every 10th wave.'
          )
        ),
        el(
          'div',
          'row',
          button('Deploy', 'primary', () => {
            app.setPaused(false);
            show('none');
          }),
          button('New map', '', newMap)
        )
      )
    );
  const showPause = (): void => {
    if (!app.paused) {
      if (mode === 'pause') show('none');
      return;
    }
    show(
      'pause',
      el(
        'div',
        'card',
        el('div', 'eyebrow', `Paused · wave ${app.game.wave}`),
        el('h1', '', 'Line halted'),
        el(
          'div',
          'row',
          button('Resume', 'primary', () => {
            app.setPaused(false);
            show('none');
          }),
          button('New map', '', newMap)
        ),
        el('p', '', 'New map ends this run.')
      )
    );
  };
  const showOver = (): void => {
    const survived = Math.max(0, app.game.wave - 1);
    best = saveBest(localStorage, best, survived);
    show(
      'over',
      el(
        'div',
        'card',
        el('div', 'eyebrow', 'Core breached'),
        el('div', 'big', String(survived)),
        el('p', '', `waves survived · best ${best}`),
        el('div', 'row', button('New map', 'primary', newMap))
      )
    );
  };
  showStart();

  // --- panel
  let panelKey = '';
  const optionCard = (o: BuildOption): HTMLButtonElement => {
    const b = button(
      '',
      'bcard',
      () => {
        const command = buildCommand(app.selection, o.id);
        if (command) app.submit(command);
      },
      !o.affordable
    );
    b.style.setProperty('--tint', TINT[o.id]);
    b.append(
      el('span', 'name', o.name),
      el('span', 'desc', o.description),
      el('span', 'cost', String(o.cost))
    );
    return b;
  };
  const renderPanel = (model: PanelModel): void => {
    if (model.kind === 'hint') {
      panel.replaceChildren(
        el(
          'div',
          'hint',
          el(
            'p',
            '',
            el('b', '', 'Tap a metal plate'),
            ' to build. Tap a tower to upgrade or sell it.'
          )
        )
      );
    } else if (model.kind === 'build') {
      panel.replaceChildren(
        el('div', 'build', ...model.options.map(optionCard))
      );
    } else {
      const pips = el('span', 'pips');
      for (let i = 0; i < 3; i++)
        pips.append(el('i', i < model.level ? 'lit' : ''));
      const stats = el('div', 'stats');
      for (const s of model.stats) {
        const value = el('div', '', el('span', '', s.label), s.value);
        if (s.next) value.append(' ', el('em', '', `→${s.next}`));
        stats.append(value);
      }
      const info = el(
        'div',
        'info',
        el('div', '', el('h3', '', model.name, pips), stats),
        el(
          'div',
          'info-buttons',
          button(
            model.upgrade ? `Upgrade · ${model.upgrade.cost}` : 'Max level',
            'primary',
            () => {
              const command = upgradeCommand(app.selection);
              if (command) app.submit(command);
            },
            !model.upgrade?.affordable || app.paused
          ),
          button(
            `Sell · +${model.sell}`,
            'sell',
            () => {
              const command = sellCommand(app.selection);
              if (command) app.submit(command);
            },
            app.paused
          )
        )
      );
      info.style.setProperty('--tint', TINT[model.id]);
      panel.replaceChildren(info);
    }
  };

  // --- per-frame refresh
  let lastRefresh = -Infinity;
  const setText = (node: HTMLElement, value: string): void => {
    if (node.textContent !== value) node.textContent = value;
  };
  const refresh = (model: HudModel): void => {
    setText(credits, String(model.credits));
    setText(lives, String(model.lives));
    livesBox.classList.toggle('low', model.lowLives);
    setText(wave, String(model.wave));
    setText(bestValue, String(best));
    setText(launch, model.launch.label);
    launch.disabled = !model.launch.enabled || app.paused;
    setText(pause, app.paused ? '▶' : 'II');
    pause.setAttribute('aria-label', app.paused ? 'Resume' : 'Pause');
    // the start and game-over cards own the pause state
    pause.disabled = mode === 'start' || mode === 'over';
    const key = JSON.stringify(model.panel) + String(app.paused);
    if (key !== panelKey) {
      panelKey = key;
      renderPanel(model.panel);
    }
  };

  app.subscribe(() => {
    for (const event of app.frameEvents) {
      const message = toastFor(event);
      if (message) say(message);
      if (event.type === 'waveCleared' && !app.autoStart && !app.game.over) {
        nextTitle.textContent = `Wave ${event.wave} cleared · +${event.bonus}`;
        nextButton.textContent = `Start wave ${event.wave + 1}`;
        next.hidden = false;
      }
      if (event.type === 'waveLaunched' || event.type === 'gameOver') {
        hideNext();
      }
      if (event.type === 'waveCleared')
        best = saveBest(localStorage, best, event.wave);
    }
    if (app.game.over && mode !== 'over') showOver();
    const now = performance.now();
    if (now - lastRefresh < REFRESH_MS) return;
    lastRefresh = now;
    refresh(hudModel(app.game, app.selection, best));
  });
}
