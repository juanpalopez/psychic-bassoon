import {GRID} from '../content';
import {CAMERA} from './camera/math';
import {GROUND_HEIGHT} from './heights';
import type {CameraState, View} from './camera/math';

const RAD = Math.PI / 180;
const HALF_FOV_TAN = Math.tan((CAMERA.fovDegrees * RAD) / 2);
const SIN_PITCH = Math.sin(CAMERA.pitchDegrees * RAD);
const COS_PITCH = Math.cos(CAMERA.pitchDegrees * RAD);

/**
 * Where a pixel's view ray meets the ground (y = 0), or undefined for a pixel
 * above the horizon. The camera looks at its target from the +z side, tilted
 * by the pitch, so its basis is right = +x, forward = (0, -sin, -cos) and up
 * = (0, cos, -sin). Pure maths: no three.js, so it is easy to test.
 */
export function groundPointAt(
  px: number,
  py: number,
  view: View,
  rig: CameraState
): {x: number; z: number} | undefined {
  const ndcX = (px / view.width) * 2 - 1;
  const ndcY = 1 - (py / view.height) * 2;
  const aspect = view.width / Math.max(view.height, 1);
  const right = ndcX * HALF_FOV_TAN * aspect;
  const up = ndcY * HALF_FOV_TAN;
  const dirY = -SIN_PITCH + up * COS_PITCH;
  if (dirY >= 0) return undefined;
  const dirZ = -COS_PITCH - up * SIN_PITCH;
  // the ground is GROUND_HEIGHT above y = 0, so the ray ends there
  const eyeY = SIN_PITCH * rig.distance - GROUND_HEIGHT;
  const eyeZ = rig.targetZ + COS_PITCH * rig.distance;
  const t = -eyeY / dirY;
  return {x: rig.targetX + right * t, z: eyeZ + dirZ * t};
}

/** The board cell under a pixel, or undefined if it is off the board. */
export function pickCell(
  px: number,
  py: number,
  view: View,
  rig: CameraState
): {col: number; row: number} | undefined {
  const point = groundPointAt(px, py, view, rig);
  if (!point) return undefined;
  const col = Math.floor(point.x);
  const row = Math.floor(point.z);
  if (col < 0 || col >= GRID.cols || row < 0 || row >= GRID.rows) {
    return undefined;
  }
  return {col, row};
}
