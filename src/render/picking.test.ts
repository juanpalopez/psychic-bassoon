import {PerspectiveCamera, Plane, Raycaster, Vector2, Vector3} from 'three';
import {describe, expect, it} from 'vitest';
import {GRID} from '../content';
import {CAMERA} from './camera/math';
import {GROUND_HEIGHT} from './heights';
import type {CameraState, View} from './camera/math';
import {groundPointAt, pickCell} from './picking';

const VIEW: View = {width: 390, height: 780};
const RIG: CameraState = {targetX: 4.5, targetZ: 6.5, distance: 24};

/** The same camera the scene builds, as a real three.js camera. */
function threeCamera(rig: CameraState, view: View): PerspectiveCamera {
  const camera = new PerspectiveCamera(
    CAMERA.fovDegrees,
    view.width / view.height,
    0.1,
    200
  );
  const pitch = (CAMERA.pitchDegrees * Math.PI) / 180;
  camera.position.set(
    rig.targetX,
    Math.sin(pitch) * rig.distance,
    rig.targetZ + Math.cos(pitch) * rig.distance
  );
  camera.lookAt(rig.targetX, 0, rig.targetZ);
  camera.updateMatrixWorld();
  return camera;
}

describe('groundPointAt', () => {
  it('maps the screen centre to the view target, lifted to the ground height', () => {
    const p = groundPointAt(195, 390, VIEW, RIG);
    expect(p?.x).toBeCloseTo(4.5, 9);
    // the centre ray crosses the ground (y = 0.2) a little before the target
    const pitch = (CAMERA.pitchDegrees * Math.PI) / 180;
    expect(p?.z).toBeCloseTo(6.5 + GROUND_HEIGHT / Math.tan(pitch), 9);
  });

  it('agrees with a three.js raycast against the ground plane', () => {
    const camera = threeCamera(RIG, VIEW);
    const raycaster = new Raycaster();
    const hit = new Vector3();
    for (let px = 5; px < VIEW.width; px += 73) {
      for (let py = 120; py < VIEW.height; py += 91) {
        raycaster.setFromCamera(
          new Vector2((px / VIEW.width) * 2 - 1, -(py / VIEW.height) * 2 + 1),
          camera
        );
        const point = raycaster.ray.intersectPlane(
          new Plane(new Vector3(0, 1, 0), -GROUND_HEIGHT),
          hit
        );
        const ours = groundPointAt(px, py, VIEW, RIG);
        expect(point).not.toBeNull();
        expect(ours?.x).toBeCloseTo(hit.x, 6);
        expect(ours?.z).toBeCloseTo(hit.z, 6);
      }
    }
  });

  it('returns nothing for a tap above the horizon', () => {
    expect(groundPointAt(195, 0, VIEW, {...RIG, distance: 24})).toBeDefined();
    const sky = groundPointAt(195, -5000, VIEW, RIG);
    expect(sky).toBeUndefined();
  });
});

describe('pickCell', () => {
  it('picks the cell under the view target at the screen centre', () => {
    expect(pickCell(195, 390, VIEW, RIG)).toEqual({col: 4, row: 6});
  });

  it('picks every cell of the board from its projected centre', () => {
    const camera = threeCamera(RIG, VIEW);
    for (let row = 0; row < GRID.rows; row++) {
      for (let col = 0; col < GRID.cols; col++) {
        const v = new Vector3(col + 0.5, 0, row + 0.5).project(camera);
        const px = ((v.x + 1) / 2) * VIEW.width;
        const py = ((1 - v.y) / 2) * VIEW.height;
        if (px < 0 || px > VIEW.width || py < 0 || py > VIEW.height) continue;
        expect(pickCell(px, py, VIEW, RIG)).toEqual({col, row});
      }
    }
  });

  it('returns nothing off the board', () => {
    const far: CameraState = {targetX: 4.5, targetZ: 6.5, distance: 24};
    expect(pickCell(0, 770, VIEW, far)).toBeUndefined();
    expect(pickCell(195, -5000, VIEW, far)).toBeUndefined();
  });

  it('follows a panned camera', () => {
    const panned: CameraState = {...RIG, targetX: 2.5, targetZ: 3.5};
    expect(pickCell(195, 390, VIEW, panned)).toEqual({col: 2, row: 3});
  });
});
