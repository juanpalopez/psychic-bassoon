import type {BufferGeometry} from 'three';
import type {EnemyId, TowerId} from '../../content';
import {buildHauler} from './hauler';
import {buildMainlineArc} from './mainline-arc';
import {buildOverseer} from './overseer';
import {buildQuenchCoil} from './quench-coil';
import {buildRivetMortar} from './rivet-mortar';
import {buildSkitter} from './skitter';
import {buildSmelter} from './smelter';
import {buildWelder} from './welder';

/**
 * The model interface: the render layers ask for geometry by unit id and
 * level and never import a unit file. Phase 3 swaps a builder for a GLB
 * loader here and nothing else changes.
 */
export const ROBOT_MODELS: Readonly<Record<EnemyId, () => BufferGeometry>> = {
  skitter: buildSkitter,
  hauler: buildHauler,
  smelter: buildSmelter,
  overseer: buildOverseer,
};

export const TOWER_MODELS: Readonly<
  Record<TowerId, (level: number) => BufferGeometry>
> = {
  welder: buildWelder,
  rivetMortar: buildRivetMortar,
  quenchCoil: buildQuenchCoil,
  mainlineArc: buildMainlineArc,
};
