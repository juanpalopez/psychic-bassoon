/** Camera rig numbers. Fixed by the plan: about 55° pitch, about 35° FOV. */
export const CAMERA = {
  fovDegrees: 35,
  pitchDegrees: 55,
  /** A grid cell never gets narrower than this many pixels. */
  minCellPixels: 40,
  /** Closest the camera may get to the view target, in cells. */
  minDistance: 7,
  /** Free space around the board when it is fitted to the screen, in cells. */
  fitMarginCells: 0.5,
} as const;

/** Where the camera looks (on the ground plane) and how far away it is. */
export interface CameraState {
  targetX: number;
  targetZ: number;
  distance: number;
}

/** Size of the canvas in CSS pixels. */
export interface View {
  readonly width: number;
  readonly height: number;
}

/** The ground area the view target may move over. */
export interface Bounds {
  readonly minX: number;
  readonly maxX: number;
  readonly minZ: number;
  readonly maxZ: number;
}

const RAD = Math.PI / 180;
const HALF_FOV_TAN = Math.tan((CAMERA.fovDegrees * RAD) / 2);
const SIN_PITCH = Math.sin(CAMERA.pitchDegrees * RAD);

/** Pixels per world unit at the view target. */
export function pixelsPerUnit(distance: number, view: View): number {
  return view.height / (2 * distance * HALF_FOV_TAN);
}

/** Furthest the camera may be while cells stay `minCellPixels` wide. */
export function maxDistance(view: View): number {
  return view.height / (2 * HALF_FOV_TAN * CAMERA.minCellPixels);
}

/** Distance at which the whole board, plus margin, fits the screen. */
export function fitDistance(view: View, bounds: Bounds): number {
  const aspect = view.width / Math.max(view.height, 1);
  const width = bounds.maxX - bounds.minX + CAMERA.fitMarginCells * 2;
  const depth = bounds.maxZ - bounds.minZ + CAMERA.fitMarginCells * 2;
  const forWidth = width / (2 * HALF_FOV_TAN * aspect);
  const forDepth = (depth * SIN_PITCH) / (2 * HALF_FOV_TAN);
  return Math.max(forWidth, forDepth);
}

/** Keeps the camera inside the zoom limits and the target on the board. */
export function clampCamera(
  state: CameraState,
  view: View,
  bounds: Bounds
): CameraState {
  const far = Math.max(CAMERA.minDistance, maxDistance(view));
  return {
    targetX: Math.min(bounds.maxX, Math.max(bounds.minX, state.targetX)),
    targetZ: Math.min(bounds.maxZ, Math.max(bounds.minZ, state.targetZ)),
    distance: Math.min(far, Math.max(CAMERA.minDistance, state.distance)),
  };
}

/** Moves the target so the world follows a finger drag of (dx, dy) pixels. */
export function panBy(
  state: CameraState,
  dxPixels: number,
  dyPixels: number,
  view: View
): CameraState {
  const ppu = pixelsPerUnit(state.distance, view);
  return {
    ...state,
    targetX: state.targetX - dxPixels / ppu,
    targetZ: state.targetZ - dyPixels / (ppu * SIN_PITCH),
  };
}

/** Pinch zoom: `scale` above 1 (fingers apart) brings the camera closer. */
export function zoomBy(state: CameraState, scale: number): CameraState {
  if (!(scale > 0)) return state;
  return {...state, distance: state.distance / scale};
}
