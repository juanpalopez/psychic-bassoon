import {GRID} from './content';
import {createInterpolator} from './render/interpolation';
import {createEffectsLayer} from './render/effects/layer';
import {createMapView} from './render/map';
import type {MapView} from './render/map';
import {pickCell} from './render/picking';
import {createScene} from './render/scene';
import {createRobotLayer, createTowerLayer} from './render/units';
import type {RobotPose, TowerPose} from './render/units';
import {createClock, createGame, stepFrame, TICK_SECONDS} from './sim';
import type {Clock, Command, FrameOptions, GameEvent, GameState} from './sim';
import {reconcileSelection, selectAt} from './ui/selection';
import type {Selection} from './ui/selection';

export interface App {
  /** The running game. Read it; change it only with `submit`. */
  readonly game: GameState;
  readonly selection: Selection;
  readonly speed: number;
  readonly paused: boolean;
  /** Queues a command for the next tick. */
  submit(command: Command): void;
  setSpeed(speed: number): void;
  setPaused(paused: boolean): void;
  /** Starts a fresh game from `seed`. */
  restart(seed: number): void;
  /** Events from every tick run this frame, for toasts and effects. */
  readonly frameEvents: readonly GameEvent[];
  /** What the renderer drew last frame (draw calls, triangles). */
  stats(): {calls: number; triangles: number};
  /** Called once a frame, after the sim and the scene are up to date. */
  subscribe(listener: () => void): void;
}

/** Wires the sim, the 3D scene and the UI together. The only place that does. */
export function createApp(container: HTMLElement, seed: number): App {
  const scene = createScene(container, GRID);
  const robots = createRobotLayer();
  const towers = createTowerLayer();
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  const effects = createEffectsLayer(() => reduced.matches);
  const interpolator = createInterpolator();
  const robotPoses: RobotPose[] = [];
  const towerPoses: TowerPose[] = [];
  const listeners: (() => void)[] = [];
  const frameEvents: GameEvent[] = [];
  scene.scene.add(robots.group, towers.group, effects.group);

  let game = createGame(seed);
  let clock: Clock = createClock();
  let mapView: MapView | undefined;
  let selection: Selection = {kind: 'none'};
  let speed = 1;
  let paused = true; // the start screen unpauses
  let lastMs: number | undefined;
  let towersDirty = true;

  const showMap = (): void => {
    if (mapView) {
      scene.scene.remove(mapView.group);
      mapView.dispose();
    }
    mapView = createMapView(game.map);
    scene.scene.add(mapView.group);
  };
  showMap();

  const syncTowers = (): void => {
    towerPoses.length = game.towers.length;
    game.towers.forEach((tower, i) => {
      towerPoses[i] = {
        type: tower.type,
        level: tower.level,
        col: tower.col,
        row: tower.row,
      };
    });
    towers.update(towerPoses);
    towersDirty = false;
  };

  scene.onTap = (x, y) => {
    selection = selectAt(game, pickCell(x, y, scene.view(), scene.rig));
  };

  // Built once: the frame loop must not allocate.
  const frameOptions: FrameOptions = {
    beforeTick: g => interpolator.capture(g),
    afterTick: g => {
      for (const event of g.events) {
        frameEvents.push(event);
        if (
          event.type === 'towerBuilt' ||
          event.type === 'towerUpgraded' ||
          event.type === 'towerSold'
        ) {
          towersDirty = true;
        }
      }
    },
  };

  let alpha = 1;
  scene.onFrame = now => {
    const elapsed = lastMs === undefined ? 0 : (now - lastMs) / 1000;
    lastMs = now;
    frameEvents.length = 0;
    if (!paused && !game.over) {
      stepFrame(game, clock, elapsed, speed, frameOptions);
      alpha = Math.min(1, clock.accumulator / TICK_SECONDS);
    }
    selection = reconcileSelection(game, selection);
    if (towersDirty) syncTowers();
    for (const event of frameEvents) effects.spawn(event);
    effects.setShells(game.shots);
    effects.update(paused ? 0 : elapsed * speed);
    interpolator.poses(game, alpha, robotPoses);
    robots.update(robotPoses);
    for (const listener of listeners) listener();
  };

  return {
    get game() {
      return game;
    },
    get selection() {
      return selection;
    },
    get speed() {
      return speed;
    },
    frameEvents,
    stats() {
      const {calls, triangles} = scene.renderer.info.render;
      return {calls, triangles};
    },
    get paused() {
      return paused;
    },
    submit(command) {
      if (!paused) game.pending.push(command);
    },
    setSpeed(next) {
      speed = next;
    },
    setPaused(next) {
      paused = next;
    },
    restart(nextSeed) {
      game = createGame(nextSeed);
      clock = createClock();
      selection = {kind: 'none'};
      towersDirty = true;
      alpha = 1;
      showMap();
    },
    subscribe(listener) {
      listeners.push(listener);
    },
  };
}
