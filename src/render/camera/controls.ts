import {zoomBy, panBy} from './math';
import type {CameraState, View} from './math';

/** A tap is a short touch that barely moves. */
const TAP_MAX_PIXELS = 8;
const TAP_MAX_MS = 350;
/** Mouse wheel zoom speed, for desktop testing. */
const WHEEL_ZOOM = 0.0015;

interface Pointer {
  x: number;
  y: number;
  startX: number;
  startY: number;
  startTime: number;
}

export interface CameraControlsOptions {
  readonly element: HTMLElement;
  readonly getState: () => CameraState;
  readonly getView: () => View;
  /** Receives the next camera state; the caller clamps and applies it. */
  readonly setState: (state: CameraState) => void;
  /** A short tap, in pixels relative to the element. */
  readonly onTap?: (x: number, y: number) => void;
}

/**
 * One finger pans, two fingers pinch to zoom and pan together, the wheel
 * zooms. Holds no camera state of its own.
 */
export function attachCameraControls(
  options: CameraControlsOptions
): () => void {
  const {element, getState, getView, setState, onTap} = options;
  const pointers = new Map<number, Pointer>();
  let moved = false;

  const spread = (): number => {
    const [a, b] = [...pointers.values()];
    return a && b ? Math.hypot(a.x - b.x, a.y - b.y) : 0;
  };
  const centre = (): {x: number; y: number} => {
    const list = [...pointers.values()];
    const n = Math.max(list.length, 1);
    return {
      x: list.reduce((sum, p) => sum + p.x, 0) / n,
      y: list.reduce((sum, p) => sum + p.y, 0) / n,
    };
  };

  const down = (e: PointerEvent): void => {
    element.setPointerCapture(e.pointerId);
    const rect = element.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    pointers.set(e.pointerId, {
      x,
      y,
      startX: x,
      startY: y,
      startTime: e.timeStamp,
    });
    if (pointers.size > 1) moved = true;
    else moved = false;
  };

  const move = (e: PointerEvent): void => {
    const pointer = pointers.get(e.pointerId);
    if (!pointer) return;
    const before = {centre: centre(), spread: spread()};
    const rect = element.getBoundingClientRect();
    pointer.x = e.clientX - rect.left;
    pointer.y = e.clientY - rect.top;
    if (
      Math.hypot(pointer.x - pointer.startX, pointer.y - pointer.startY) >
      TAP_MAX_PIXELS
    ) {
      moved = true;
    }
    if (!moved) return;
    const after = {centre: centre(), spread: spread()};
    let next = panBy(
      getState(),
      after.centre.x - before.centre.x,
      after.centre.y - before.centre.y,
      getView()
    );
    if (pointers.size > 1 && before.spread > 0 && after.spread > 0) {
      next = zoomBy(next, after.spread / before.spread);
    }
    setState(next);
  };

  const up = (e: PointerEvent): void => {
    const pointer = pointers.get(e.pointerId);
    pointers.delete(e.pointerId);
    if (
      pointer &&
      !moved &&
      pointers.size === 0 &&
      e.timeStamp - pointer.startTime <= TAP_MAX_MS
    ) {
      onTap?.(pointer.x, pointer.y);
    }
  };

  const wheel = (e: WheelEvent): void => {
    e.preventDefault();
    setState(zoomBy(getState(), Math.exp(-e.deltaY * WHEEL_ZOOM)));
  };

  element.addEventListener('pointerdown', down);
  element.addEventListener('pointermove', move);
  element.addEventListener('pointerup', up);
  element.addEventListener('pointercancel', up);
  element.addEventListener('wheel', wheel, {passive: false});
  return () => {
    element.removeEventListener('pointerdown', down);
    element.removeEventListener('pointermove', move);
    element.removeEventListener('pointerup', up);
    element.removeEventListener('pointercancel', up);
    element.removeEventListener('wheel', wheel);
  };
}
