---
type: decision
date: 2026-10-17
status: accepted
decided-by: owner on Claude's proposal
links: [#147, #149]
---
# Draw the road as masking tape and dress the board in the papercraft look

## Context
The board drew the greybox terrain models as flat colours, and the open mat looked empty. The road's look was open (#147, #149: printed line, tape or ribbon). The renderer is GL Compatibility, so there is no real subsurface scattering, SSAO or GI, and the phone budget is under 120 draw calls a frame with 80 foes and every tower.

## Decision
- The road is masking tape, built at run time from the map's routes (`TapeBuilder`): one strip per straight run of each stretch of untaped road, overlapping at the corners, with torn ends, so it works for every seed, a feeder and a detour.
- Socket rises stay at 0, 1 and 2 m (`Board.LEVEL_HEIGHTS`); level 1 is stacked corrugated cardboard, level 2 laminated grey board stepped in on the outside of its block.
- Every board model wears a shader from `render/paper/`, chosen by its Blender material name (`PaperLook`); props carry their colours as vertex colours on one `PK_PaperVC` surface, so each prop is one draw call.
- Paper trees, shrubs, grass and flowers fill the open mat (trees two cells off the road, the rest one), and desk clutter fills the skirt. Placement is a hash of cell and seed, never a random stream.
- Lighting is one warm directional desk lamp with orthogonal shadows and a cool ambient fill. The rises, trees, shrubs, the desk's erasers and pencils and the Heartstone cast shadows; the mat, lane, tape, circles, desk, flat decor and the spilled ink do not.
- Board look colours live as `source_color` uniforms in `render/paper/*.gdshader` and in the `main.tscn` Environment, not in the HUD Theme.

## Alternatives considered
- Baked lightmaps for the board: the board is generated at run time per seed, so there is nothing to bake ahead.
- One material per prop colour: 101 draw calls on an empty board against 36 with vertex colours (the old greybox board: 24).
- A printed line or a dirt ribbon for the road: tape reads best on the cutting mat and keeps the grid visible beside it.

## Consequences
- The board, its decor and their shadows use about a third of the draw-call budget; `test_board_paper.gd` holds that line (32 surfaces drawn, 12 in the shadow map).
- The 60 fps phone check with 80 foes must be run again with shadows on (Phase 5 gate).
- Models come from `assets-src/papercraft/godot_kit.py`; textures from `assets-src/papercraft/textures.py`. Re-run them in Blender after changing a piece.
