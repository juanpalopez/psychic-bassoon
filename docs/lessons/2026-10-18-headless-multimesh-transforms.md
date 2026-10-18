---
type: lesson
date: 2026-10-18
area: render
links: [#320]
promote: checklist
promoted-to: docs/REVIEW-CHECKLIST.md (What to check, 4. Tests)
---
# Never read MultiMesh instance transforms back in a headless test

## What happened
On the 32x20 board `test_paperboard_tiles_step_in_on_the_outside_of_their_block` failed. Every Paperboard instance read back as the identity at the origin, so the test had only ever checked where the board's first level 2 block lay, and passed on 16x11 because that block happened to sit where the identity pointed outwards.

## Evidence
`multimesh.get_instance_transform(i)` printed `[X: (1.0, 0.0, 0.0), ... O: (0.0, 0.0, 0.0)]` for all 8 tiles of seed 1; the failure was `[-1.0] expected to be > than [0.0]: (14, 11)` at `godot/tests/render/test_board_paper.gd:295`.

## What we learnt
`--headless` runs the dummy renderer, which keeps no MultiMesh buffer: what the board wrote is not what a test reads back. A render test must check the values the node computed (a stored seam such as `Board.socket_transform`, or the function that makes the transform), not the server's copy.

## Rule next time
In a GUT test, check a MultiMesh's `instance_count` but never its instance transforms or colours; test the function or stored array that computed them.
