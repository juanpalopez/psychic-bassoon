import {PerspectiveCamera, Scene, WebGLRenderer} from 'three';
import {attachCameraControls} from './camera/controls';
import {CAMERA, clampCamera, fitDistance} from './camera/math';
import type {Bounds, CameraState, View} from './camera/math';

const MAX_PIXEL_RATIO = 2;
const CLEAR_COLOR = 0x0f1216;
const PITCH = (CAMERA.pitchDegrees * Math.PI) / 180;

/** Board size in cells; the camera may pan anywhere over it. */
export interface Board {
  readonly cols: number;
  readonly rows: number;
}

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

export function createScene(container: HTMLElement, board: Board): SceneHandle {
  const renderer = new WebGLRenderer({antialias: true});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
  renderer.setClearColor(CLEAR_COLOR);
  container.appendChild(renderer.domElement);

  const scene = new Scene();
  const camera = new PerspectiveCamera(CAMERA.fovDegrees, 1, 0.1, 200);
  const bounds: Bounds = {minX: 0, maxX: board.cols, minZ: 0, maxZ: board.rows};
  const rig: CameraState = {
    targetX: board.cols / 2,
    targetZ: board.rows / 2,
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
