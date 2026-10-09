import {describe, expect, it} from 'vitest';
import {createSelectionMarker} from './selection-marker';

describe('selection marker', () => {
  it('is hidden until something is selected', () => {
    const marker = createSelectionMarker();
    expect(marker.group.visible).toBe(false);
  });

  it('sits on the selected cell centre', () => {
    const marker = createSelectionMarker();
    marker.show({col: 3, row: 5});
    expect(marker.group.visible).toBe(true);
    expect([marker.group.position.x, marker.group.position.z]).toEqual([
      3.5, 5.5,
    ]);
  });

  it('shows a range ring only for a tower, as wide as its range', () => {
    const marker = createSelectionMarker();
    marker.show({col: 1, row: 1});
    const ring = marker.group.getObjectByName('range');
    expect(ring?.visible).toBe(false);
    marker.show({col: 1, row: 1, range: 2.6});
    expect(ring?.visible).toBe(true);
    expect(ring?.scale.x).toBe(2.6);
  });

  it('hides again and disposes cleanly', () => {
    const marker = createSelectionMarker();
    marker.show({col: 1, row: 1});
    marker.show(undefined);
    expect(marker.group.visible).toBe(false);
    expect(() => marker.dispose()).not.toThrow();
  });
});
