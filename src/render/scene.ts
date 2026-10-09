import {Fog, PerspectiveCamera, Scene, WebGLRenderer} from 'three';
import {attachCameraControls} from './camera/controls';
import {PALETTE} from './palette';
import {BOARD_WORLD} from './space';
import {CAMERA, clampCamera, fitDistance} from './camera/math';
import type {Bounds, CameraState, View} from './camera/math';

const MAX_PIXEL_RATIO = 2;
/** Fog starts this far behind the board's centre and thickens over the next stretch. */
const FOG_START_BEHIND = 9;
const FOG_LENGTH = 22;
const PITCH = (CAMERA.pitchDegrees * Math.PI) / 180;

export interface SceneHandle {
  readonly renderer: WebGLRenderer;
  readonly scene: Scene;
  readonly camera: PerspectiveCamera;
  readonly rig: CameraState;
  view(): View;
  /** Called every frame, before the scene is drawn. */
  onFrame: ((nowMs: number) => void) | undefined;
  /** Called with a short tap's position in canvas pixels. */
  onTap: ((x: number, y: number) => void) | undefined;
  dispose(): void;
}

export function createScene(container: HTMLElement): SceneHandle {
  const renderer = new WebGLRenderer({antialias: true});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
  renderer.setClearColor(PALETTE.clear);
  container.appendChild(renderer.domElement);

  const scene = new Scene();
  // edge mist: the scenery ring fades into the dusk sky
  const fog = new Fog(PALETTE.clear, 1, 2);
  scene.fog = fog;
  const camera = new PerspectiveCamera(CAMERA.fovDegrees, 1, 0.1, 200);
  const bounds: Bounds = {
    minX: 0,
    maxX: BOARD_WORLD.width,
    minZ: 0,
    maxZ: BOARD_WORLD.depth,
  };
  const rig: CameraState = {
    targetX: BOARD_WORLD.width / 2,
    targetZ: BOARD_WORLD.depth / 2,
    distance: 20,
  };
  const view = (): View => ({
    width: container.clientWidth,
    height: container.clientHeight,
  });

  const apply = (next: CameraState): void => {
    const clamped = clampCamera(next, view(), bounds);
    rig.targetX = clamped.targetX;
    rig.targetZ = clamped.targetZ;
    rig.distance = clamped.distance;
    camera.position.set(
      rig.targetX,
      Math.sin(PITCH) * rig.distance,
      rig.targetZ + Math.cos(PITCH) * rig.distance
    );
    camera.lookAt(rig.targetX, 0, rig.targetZ);
    // keep the playfield clear of fog at any zoom: only the far scenery fades
    fog.near = rig.distance + FOG_START_BEHIND;
    fog.far = fog.near + FOG_LENGTH;
  };

  const handle: SceneHandle = {
    renderer,
    scene,
    camera,
    rig,
    view,
    onFrame: undefined,
    onTap: undefined,
    dispose(): void {
      window.removeEventListener('resize', resize);
      window.visualViewport?.removeEventListener('resize', resize);
      detach();
      renderer.setAnimationLoop(null);
      renderer.dispose();
      renderer.domElement.remove();
    },
  };

  const resize = (): void => {
    const {width, height} = view();
    renderer.setSize(width, height);
    camera.aspect = width / Math.max(height, 1);
    camera.updateProjectionMatrix();
    // Re-clamp: a rotated phone changes how far the camera may zoom out.
    apply(rig);
  };
  resize();
  // Start fitted to the whole board.
  apply({
    ...rig,
    distance: fitDistance(view(), bounds),
  });
  window.addEventListener('resize', resize);
  // iOS Safari changes the visual viewport as its toolbars come and go
  window.visualViewport?.addEventListener('resize', resize);

  const detach = attachCameraControls({
    element: renderer.domElement,
    getState: () => rig,
    getView: view,
    setState: apply,
    onTap: (x, y) => handle.onTap?.(x, y),
  });

  renderer.setAnimationLoop(now => {
    handle.onFrame?.(now);
    renderer.render(scene, camera);
  });

  return handle;
}
