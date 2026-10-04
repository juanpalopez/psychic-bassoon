import {PerspectiveCamera, Scene, WebGLRenderer} from 'three';

const MAX_PIXEL_RATIO = 2;
const FOV_DEGREES = 35;
const PITCH_DEGREES = 55;
const CAMERA_DISTANCE = 20;
const CLEAR_COLOR = 0x0f1216;

export interface SceneHandle {
  readonly renderer: WebGLRenderer;
  readonly scene: Scene;
  readonly camera: PerspectiveCamera;
  dispose(): void;
}

export function createScene(container: HTMLElement): SceneHandle {
  const renderer = new WebGLRenderer({antialias: true});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
  renderer.setClearColor(CLEAR_COLOR);
  container.appendChild(renderer.domElement);

  const scene = new Scene();
  const camera = new PerspectiveCamera(FOV_DEGREES, 1, 0.1, 200);
  const pitch = (PITCH_DEGREES * Math.PI) / 180;
  camera.position.set(
    0,
    Math.sin(pitch) * CAMERA_DISTANCE,
    Math.cos(pitch) * CAMERA_DISTANCE
  );
  camera.lookAt(0, 0, 0);

  const resize = (): void => {
    const {clientWidth, clientHeight} = container;
    renderer.setSize(clientWidth, clientHeight);
    camera.aspect = clientWidth / Math.max(clientHeight, 1);
    camera.updateProjectionMatrix();
  };
  resize();
  window.addEventListener('resize', resize);

  renderer.setAnimationLoop(() => renderer.render(scene, camera));

  return {
    renderer,
    scene,
    camera,
    dispose(): void {
      window.removeEventListener('resize', resize);
      renderer.setAnimationLoop(null);
      renderer.dispose();
      renderer.domElement.remove();
    },
  };
}
