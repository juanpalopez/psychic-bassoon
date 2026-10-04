import {describe, expect, it} from 'vitest';
import {
  CAMERA,
  clampCamera,
  fitDistance,
  maxDistance,
  panBy,
  pixelsPerUnit,
  zoomBy,
} from './math';
import type {Bounds, CameraState, View} from './math';

const PHONE: View = {width: 360, height: 640};
const BOUNDS: Bounds = {minX: 0, maxX: 9, minZ: 0, maxZ: 13};
const tan = (deg: number) => Math.tan((deg * Math.PI) / 360);

describe('pixelsPerUnit', () => {
  it('is the view height over the world height seen at that distance', () => {
    const d = 20;
    expect(pixelsPerUnit(d, PHONE)).toBeCloseTo(
      PHONE.height / (2 * d * tan(CAMERA.fovDegrees)),
      9
    );
  });

  it('halves when the camera moves twice as far away', () => {
    expect(pixelsPerUnit(40, PHONE)).toBeCloseTo(
      pixelsPerUnit(20, PHONE) / 2,
      9
    );
  });
});

describe('maxDistance', () => {
  it('keeps a cell at least the minimum width in pixels', () => {
    expect(pixelsPerUnit(maxDistance(PHONE), PHONE)).toBeCloseTo(
      CAMERA.minCellPixels,
      9
    );
  });

  it('allows more zoom-out on a taller screen', () => {
    expect(maxDistance({width: 360, height: 800})).toBeGreaterThan(
      maxDistance(PHONE)
    );
  });
});

describe('fitDistance', () => {
  it('shows the whole board with its margin, in portrait', () => {
    const d = fitDistance(PHONE, BOUNDS);
    const width = 2 * d * tan(CAMERA.fovDegrees) * (PHONE.width / PHONE.height);
    const depth =
      (2 * d * tan(CAMERA.fovDegrees)) /
      Math.sin((CAMERA.pitchDegrees * Math.PI) / 180);
    expect(width).toBeGreaterThanOrEqual(9 + CAMERA.fitMarginCells * 2 - 1e-9);
    expect(depth).toBeGreaterThanOrEqual(13 + CAMERA.fitMarginCells * 2 - 1e-9);
  });
});

describe('clampCamera', () => {
  const state = (over: Partial<CameraState>): CameraState => ({
    targetX: 4.5,
    targetZ: 6.5,
    distance: 20,
    ...over,
  });

  it('leaves a legal camera alone', () => {
    const legal = state({distance: Math.min(20, maxDistance(PHONE))});
    expect(clampCamera(legal, PHONE, BOUNDS)).toEqual(legal);
  });

  it('stops zooming out when cells would be narrower than the minimum', () => {
    const out = clampCamera(state({distance: 500}), PHONE, BOUNDS);
    expect(out.distance).toBeCloseTo(maxDistance(PHONE), 9);
    expect(pixelsPerUnit(out.distance, PHONE)).toBeGreaterThanOrEqual(
      CAMERA.minCellPixels - 1e-9
    );
  });

  it('stops zooming in at the minimum distance', () => {
    expect(clampCamera(state({distance: 0.1}), PHONE, BOUNDS).distance).toBe(
      CAMERA.minDistance
    );
  });

  it('keeps the view target on the board', () => {
    const far = clampCamera(state({targetX: -50, targetZ: 90}), PHONE, BOUNDS);
    expect(far.targetX).toBe(BOUNDS.minX);
    expect(far.targetZ).toBe(BOUNDS.maxZ);
    const other = clampCamera(
      state({targetX: 50, targetZ: -90}),
      PHONE,
      BOUNDS
    );
    expect(other.targetX).toBe(BOUNDS.maxX);
    expect(other.targetZ).toBe(BOUNDS.minZ);
  });

  it('never lets the minimum distance beat the pixel limit on a tiny screen', () => {
    const tiny: View = {width: 100, height: 40};
    const out = clampCamera(state({distance: 1}), tiny, BOUNDS);
    expect(out.distance).toBeGreaterThanOrEqual(CAMERA.minDistance);
  });
});

describe('panBy', () => {
  const start: CameraState = {targetX: 4.5, targetZ: 6.5, distance: 12};

  it('drags the world with the finger: a drag right moves the target left', () => {
    const ppu = pixelsPerUnit(12, PHONE);
    const moved = panBy(start, 100, 0, PHONE);
    expect(moved.targetX).toBeCloseTo(4.5 - 100 / ppu, 9);
    expect(moved.targetZ).toBe(6.5);
  });

  it('stretches vertical drags by the tilt of the ground', () => {
    const ppu = pixelsPerUnit(12, PHONE);
    const sin = Math.sin((CAMERA.pitchDegrees * Math.PI) / 180);
    expect(panBy(start, 0, 50, PHONE).targetZ).toBeCloseTo(
      6.5 - 50 / (ppu * sin),
      9
    );
  });

  it('does not change the distance', () => {
    expect(panBy(start, 30, 30, PHONE).distance).toBe(12);
  });
});

describe('zoomBy', () => {
  it('pinching apart (scale 2) halves the distance', () => {
    expect(zoomBy({targetX: 0, targetZ: 0, distance: 20}, 2).distance).toBe(10);
  });

  it('ignores a zero or negative scale', () => {
    const s: CameraState = {targetX: 0, targetZ: 0, distance: 20};
    expect(zoomBy(s, 0)).toEqual(s);
    expect(zoomBy(s, -1)).toEqual(s);
  });
});
