---
type: lesson
date: 2026-10-25
area: ui
links: [#329, #544]
promote: checklist
promoted-to:
---
# Test a HUD control inside its real node tree, not only its pure functions

## What happened
`EdgeIndicators` (#544) had green tests for `EdgeArrows.spot`, `room` and `ArrowTargets`, yet no arrow ever drew in the game. A desktop screenshot pass found it.

## Evidence
`arrows size (0.0, 0.0) anchors 1.01.0 offs -1280.0-720.0 parent CanvasLayer`: `set_anchors_preset(PRESET_FULL_RECT)` keeps the offsets it had, so under the HUD's CanvasLayer the control ended 0 by 0. Test: `godot/tests/ui/test_edge_indicators_tree.gd`.

## What we learnt
Layout (anchors, offsets, parents, viewport size) exists only in the tree; unit tests that pass a size in by hand never exercise it. The start view had the same shape: it was framed once, before the window size settled (`godot/tests/test_start_view_resize.gd`).

## Rule next time
For every new HUD Control or camera framing, add one test that builds the real parent chain in a SubViewport, waits a frame and asserts the size or the drawn result.
