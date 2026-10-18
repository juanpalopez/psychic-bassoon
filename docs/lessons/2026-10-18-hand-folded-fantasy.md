---
type: decision
date: 2026-10-18
status: accepted
decided-by: owner on Claude's proposal
links: [#316, #317]
---
# Adopt the Hand-Folded Fantasy look and drop the desk-top framing

## Context
The owner found the board on the cutting mat "kind of lame" next to the Blender renders: a rectangular table that does not feel like a natural, integrated scene. They supplied a reference diorama, a foe sheet and a brief (painterly low-poly world, chunky squarish paper characters, warm light, cool magic, strong contact shading, tilt-shift). A toon-band pass was tried in the look-dev and rejected ("painterly, not flat").

## Decision
- The style is "Hand-Folded Fantasy", written in `docs/art/STYLE.md`: squarish not voxel, painterly not flat, paper not plastic, readable at gameplay distance.
- The world is a boundless papercraft valley (terraces, canyon walls, river, forest, rocks, dirt); no desk, mat, tape road or table edge. The lore stays: the Grand Crafter made the kingdom, the Blot corrupts it.
- Supersedes `2026-10-17-papercraft-board-look.md` (the tape road, the mat and the desk clutter); its rules on vertex-colour props (one draw call each), shadow casters and `source_color` uniforms carry over.

## Alternatives considered
- Keep the board on the desk and add a diorama on top: still a table with an edge.
- Toon or cel shading: rejected by the owner after the look-dev pass.

## Consequences
- The board tiles, `TapeBuilder` and the desk decor are replaced by #324, #325 and #326; #293 is closed as not planned.
- Where `docs/GDD.md` says cutting mat, desk or tape road, this record and `STYLE.md` win until the owner updates the GDD.
