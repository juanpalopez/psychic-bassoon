---
type: decision
date: 2026-10-18
status: accepted
decided-by: owner on Claude's proposal
links: [#292]
---
# Build the towers, the guard and the Camp Cook as stop-motion papercraft models

## Context
The towers were static greybox models scaled down to fit their blocks, and the guards were purple capsules. The owner asked for hi-def towers with animations, the guards of the Guard Tent and the chef (the GDD's Camp Cook), reviewed as Blender renders first. The plan already says a tower is at most 3 mesh parts animated in an `AnimationPlayer`, with no skeleton, stepping at 12 fps like stop-motion. The phone budget is under 120 draw calls and about 150k triangles a frame (towers at most 45k in total).

## Decision
- Each tower, the guard and the Camp Cook is built from craft-room objects by `assets-src/papercraft/` scripts (`towers_hd.py`, one file per model, `towers_export.py` writes the GLBs): a thread spool with a lolly-stick crossbow, a dimpled brass thimble mortar, a rolled-paper spire with a glass marble, a striped origami tent, a cardboard-box mess hall, a guard in the tent's stripes with a bottle-cap shield, and a recipe-paper chef with a foil ladle.
- At most 3 parts a model: a Base (or Body) and two moving parts. A tower whose look `aims` (Spool Guard, Thimble Mortar) has an `*_Aim` empty above its `*_Head` that no clip moves; the game turns it to what the tower shot, so the aim holds while the clips play.
- Clips are data in the scripts and are exported as glTF animations keyed at 12 fps: `idle` and `fire` (`deploy` for the Guard Tent, `serve` for the Mess Tent); the guard has `idle`, `strike`, `fall` and `rise`; the Camp Cook `idle`, `walk`, `attack`, `splash`, `fall` and `rise`. Every clip keys every channel that any clip moves on every animated part (at rest where the clip leaves it alone), because Godot's mixer does not promise to keep a channel that the playing clip has no track for. The GLBs import at `animation/fps=12` with immutable tracks kept, and `StopMotion` sets every track to nearest interpolation, so the clips step at 12 fps.
- Every part is one surface: the exporter merges all looks into one `PK_Craft` material and writes the look of each face (paper, wood, metal, dimpled metal, thread, corrugated card) into UV2, read by `render/paper/craft_vc.gdshader`. Only the marble's shell is a second surface (`glass.gdshader`).
- Only a tower's Base casts a shadow; the guard casts none. A tower is 3 surfaces (the Prism Spire 4, its marble shell being the fourth), so 22 towers are at most 88 surfaces and 22 shadow casters (110 draws); each guard adds 3 more, so a board of Guard Tents is the case to measure on the phone.
- The shooting towers are about 2,000 to 2,100 triangles and the tents 700 to 1,600, so 22 towers stay near the plan's 45k cap.
- `TowersView` remakes a tower's view only when that tower changes, so the other towers keep their clips and aim; a clip asked for before the view exists (a tent's first guard) plays when it is made.
- Models are built at their real size (`model_scale` 1.0) and their top tier stays inside the 2x2 block.
- The guard falls flat and is hidden once its fall is over, and springs back up when it is raised again.

## Alternatives considered
- One material per look: 3 to 9 draw calls a tower, over the budget with 22 towers.
- A skeleton per tower or unit: the plan keeps skeletons for bosses and the hero; part animation is enough for things that turn, swing and fall.
- Sampling the clips at 30 fps with linear blending: smooth, but not the stop-motion look the GDD asks for.

## Consequences
- Tiers 2 and 3 still only grow the model; tier 4 specialisations show no part of their own yet.
- The Mess Tent's `serve` clip has no game event to play it yet.
- The Camp Cook model is ready, but the hero is not in the game yet.
- New looks go into `craft_vc` as a new UV2 kind, not as a new material.
