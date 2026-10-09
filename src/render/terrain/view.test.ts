import {describe, expect, it} from 'vitest';
import {generateMap} from '../../sim';
import type {ModelLibrary} from '../models/library';
import {createTerrainView} from './view';

const library = (ready: boolean): ModelLibrary =>
  ({
    terrainReady: ready,
    prop: () => undefined,
    extra: () => undefined,
  }) as unknown as ModelLibrary;

describe('createTerrainView', () => {
  it('returns nothing when the terrain tiles did not load, so the primitive map is used', () => {
    expect(createTerrainView(generateMap(42), library(false))).toBeUndefined();
  });

  it('returns nothing if a tile it needs is missing even when marked ready', () => {
    expect(createTerrainView(generateMap(42), library(true))).toBeUndefined();
  });
});
