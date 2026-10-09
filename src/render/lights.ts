import type {Group} from 'three';
import {DirectionalLight, HemisphereLight} from 'three';
import {BOARD_WORLD} from './space';

/** Dusk: cool sky fill, warm low key light, dark mossy bounce. */
const SKY = 0x6f82c0;
const GROUND = 0x243020;
const KEY = 0xffc98a;

export function addLights(group: Group): void {
  const key = new DirectionalLight(KEY, 2);
  // from the camera side and a little to the left, in the turned frame
  key.position.set(BOARD_WORLD.width * 0.3, 10, BOARD_WORLD.depth + 6);
  group.add(key, new HemisphereLight(SKY, GROUND, 1.1));
}
