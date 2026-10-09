import type {BufferGeometry} from 'three';
import type {EnemyId, TowerId} from '../../content';
import {buildRaider} from './raider';
import {buildStormSpire} from './storm-spire';
import {buildWarlord} from './warlord';
import {buildFrostSpire} from './frost-spire';
import {buildCatapult} from './catapult';
import {buildScamp} from './scamp';
import {buildIronclad} from './ironclad';
import {buildBallista} from './ballista';

/**
 * The model interface: the render layers ask for geometry by unit id and
 * level and never import a unit file. Phase 3 swaps a builder for a GLB
 * loader here and nothing else changes.
 */
export const FOE_MODELS: Readonly<Record<EnemyId, () => BufferGeometry>> = {
  scamp: buildScamp,
  raider: buildRaider,
  ironclad: buildIronclad,
  warlord: buildWarlord,
};

export const TOWER_MODELS: Readonly<
  Record<TowerId, (level: number) => BufferGeometry>
> = {
  ballista: buildBallista,
  catapult: buildCatapult,
  frostSpire: buildFrostSpire,
  stormSpire: buildStormSpire,
};
