import type {Group} from 'three';
import {DirectionalLight, HemisphereLight} from 'three';
import {GRID} from '../content';

/** Dusk: cool sky fill, warm low key light, dark mossy bounce. */
const SKY = 0x6f82c0;
const GROUND = 0x243020;
const KEY = 0xffc98a;

export function addLights(group: Group): void {
  const key = new DirectionalLight(KEY, 2);
  key.position.set(-GRID.cols * 0.5, 9, GRID.rows + 4);
  group.add(key, new HemisphereLight(SKY, GROUND, 1.1));
}
