import {
  DoubleSide,
  Group,
  Mesh,
  MeshBasicMaterial,
  PlaneGeometry,
  RingGeometry,
} from 'three';
import {RULES} from '../content';
import type {Highlight} from '../ui/selection';
import {GROUND_HEIGHT} from './heights';
import {PALETTE} from './palette';

const MARKER_HEIGHT = GROUND_HEIGHT + 0.02;

export interface SelectionMarker {
  readonly group: Group;
  /** Marks a cell (and a tower's range), or hides the marker. */
  show(highlight: Highlight | undefined): void;
  dispose(): void;
}

/**
 * The selected cell: an outlined, tinted square, plus a ring as wide as the
 * tower's range when a tower is selected. One group, three small meshes.
 */
export function createSelectionMarker(): SelectionMarker {
  const group = new Group();
  group.name = 'selection';
  group.visible = false;

  const line = new MeshBasicMaterial({
    color: PALETTE.selection,
    side: DoubleSide,
    transparent: true,
    depthWrite: false,
  });
  const fill = new MeshBasicMaterial({
    color: PALETTE.selection,
    transparent: true,
    opacity: 0.22,
    depthWrite: false,
    side: DoubleSide,
  });
  // a 4-sided ring turned 45 degrees is a square outline
  const frameGeometry = new RingGeometry(0.62, 0.72, 4).rotateZ(Math.PI / 4);
  const fillGeometry = new PlaneGeometry(1, 1);
  const rangeGeometry = new RingGeometry(0.97, 1, 64);

  const frame = new Mesh(frameGeometry, line);
  const tile = new Mesh(fillGeometry, fill);
  const range = new Mesh(rangeGeometry, line);
  range.name = 'range';
  range.visible = false;
  for (const mesh of [frame, tile, range]) {
    mesh.rotation.x = -Math.PI / 2;
    mesh.renderOrder = 2;
    group.add(mesh);
  }

  return {
    group,
    show(highlight) {
      if (!highlight) {
        group.visible = false;
        return;
      }
      group.visible = true;
      group.position.set(
        highlight.col + RULES.cellCentre,
        MARKER_HEIGHT,
        highlight.row + RULES.cellCentre
      );
      range.visible = highlight.range !== undefined;
      if (highlight.range !== undefined) range.scale.setScalar(highlight.range);
    },
    dispose() {
      for (const item of [
        line,
        fill,
        frameGeometry,
        fillGeometry,
        rangeGeometry,
      ]) {
        item.dispose();
      }
    },
  };
}
