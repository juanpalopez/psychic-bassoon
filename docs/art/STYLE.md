# Art direction: Hand-Folded Fantasy

_Adopted by the owner on 2026-10-18 (#316, #317). Decision record: `docs/lessons/2026-10-18-hand-folded-fantasy.md`. It replaces the desk-top look (a board on a green cutting mat, a masking-tape road, desk clutter) of `docs/lessons/2026-10-17-papercraft-board-look.md`._

**In one line:** a stylised 3D papercraft diorama of a fantasy valley. The places are painterly, faceted low-poly; the people are chunky, squarish paper figures. The world is lit warm and the magic glows cool, with deep contact shadows, haze and a tilt-shift.

The kingdom is a world the Grand Crafter folded out of paper and card. There is no desk, cutting mat or table edge on screen. The lore stays the same: the Blot's purple ink still corrupts the paper folk (owner, 2026-10-18).

## The four rules

1. **Squarish, not voxel.** Characters and props are chunky blocks of folded card with bevelled, slightly soft edges and a few big planes. They are not cubes on a grid, they don't stack into pixels, and they are not smooth like clay.
2. **Painterly, not flat.** Surfaces get soft gradients: warm where the key light hits and cool where it doesn't. Light falls off across a face, and there is ambient occlusion in the creases. No toon bands, no cel steps, no flat fills. (A toon pass was tried on 2026-10-18 and rejected.)
3. **Paper, not plastic.** Everything is matte: rough card, kraft and cardboard, with fibre in the albedo, corrugation as real geometry on cliffs and edges, and fold lines and torn or cut edges where they read. Nothing is glossy or metallic, and there is no plastic specular. The only things that shine are water and magic.
4. **Readable at gameplay distance.** At the overview zoom, silhouette and colour tell you the type of every foe, tower and hero. Detail that only shows close up is a bonus, never the only cue. If a model doesn't read, change the model, not this rule.

## The world (environments)

- **Shape.** The terrain is a valley in terraces: grassy shelves stepped down to the road, canyon walls cut as stacked layers of corrugated card with a dark soil lip, and a river in a gorge. The faces are faceted and low-poly (big triangles, flat-shaded within a facet, soft between facets through vertex colour). The world carries on past the playable area and fades into haze. There is no edge, rim or plinth.
- **Road.** Packed earth and flagstones in warm sand and tan, a little lower than the grass, with a darker worn edge. It curves through corners and over the terraces. Bridges are plank-and-rope or plank-and-trestle in kraft and tan, with room for the guards who hold them.
- **Scatter.** Forest patches of faceted cone pines and round broadleaf trees, grey-brown boulders split into facets, dirt patches and grass tufts. It is dense outside the play area and sparse beside the road. Props never cover a socket, the road or a bridge.
- **Water.** Light-to-deep blue with a soft sheen and white foam where it breaks. It is the one surface allowed to be glossy.

## The people (characters)

- **Proportions.** Chunky and squarish: big blocky heads and torsos, short limbs, simple faces (dot or slot eyes, a cut mouth), and parts that look folded and glued, with visible tabs and seams.
- **The cast** (from the owner's foe sheet and character references):
  - Scrap Goblin: green, ragged newsprint-and-card goblin.
  - Corrugated Orc: brown corrugated card, with a shield.
  - Cardboard Golem: a shipping box with cool glowing eyes.
  - Ink Shaman: purple and hooded, with a cool magic glow.
  - Razor Moth: origami, with crisp folded wings.
  - Knight of Cardboard (the hero): blue.
- **Movement.** Characters and projectiles step at 12 fps like stop-motion, while the camera moves smoothly at 60.
- **Towers.** Towers keep their spool, tent, prism, thimble and kitchen forms, rebuilt in the same chunky card language. Each tier adds a visible part.

## Light, colour and atmosphere

- **Key light.** Warm amber sun, low to mid height, with soft long shadows. The sky fill is cool and pale.
- **Magic.** Cool cyan (and the Blot's purple) emissive, with a soft glow. Magic is the cool accent against the warm world; keep it rare enough to read.
- **Contact shading.** Strong ambient occlusion where things meet the ground, in creases and under overhangs: SSAO on desktop, baked into vertex colour on the phone.
- **Atmosphere.** Depth haze towards the horizon, height fog that settles in the canyons, and a gentle warm-highlight, cool-shadow grade. A tilt-shift depth of field keeps the play area sharp and softens the edges.

**Starting palette.** These are look-dev values. The shader uniforms and the Environment are the truth once the look is built.

| Use | sRGB |
| --- | --- |
| Grass, lit / dry / shade | `#6f8f3a` / `#a39a52` / `#4a6a2c` |
| Cliff card (kraft) / dark layer | `#b9773c` / `#5a3418` |
| Soil lip, deep shade | `#3e2b1c` |
| Road light / worn edge | `#d9b98a` / `#b89262` |
| Stone | `#9b8b78`, `#a89a86`, `#8c7b68` |
| Water light / deep | `#7fc4f2` / `#2f6fbf` |
| Planks / rope | `#b88a55` / `#8a6a45` |
| Sun / sky | `#ffd9a8` / `#b9cbe0` |
| Warm haze | `#c7bdb3` |
| Magic | cool cyan (to be picked in #327; must glow against `#ffd9a8` light) and the Blot's purple |

## Renderers

The desktop build uses Forward+: SSAO, SSIL, volumetric fog, glow and depth of field. The iOS build uses the Mobile renderer, which has no SSAO and no volumetric fog. To make up for it, the phone bakes contact shading into vertex colour, uses height and depth fog from the Environment, and keeps glow and depth of field. Both must read as the same game; the phone may be softer and simpler, never a different style.

## What it is not

- It is not a desk-top diorama: no cutting mat, no tape road, no pencils or erasers, no table edge.
- It is not flat origami, cel shading or toon bands.
- It is not voxel or Minecraft-like.
- It is not glossy plastic or metal.
- It is not dark or desaturated: the world is warm and sunlit, and the Blot's corruption is the dark accent.

## Reference

- `docs/art/diorama/mock-24x16.jpg`: the look-dev mock (24x16 cells, before the owner chose 32x20). It shows the game on `main` at the time, then the mock zoomed out, at the game camera, and close in on the rope bridge.
- `docs/art/diorama/mock-early.jpg`: the first look-dev pass (terraces and cliffs).
- `assets-src/diorama_lookdev/`: the Blender script that built the mock (`diorama_lookdev.py`), the mock board (`board_large.py` and `board_large.json`) and the post pass (`post.py`, numpy). It covers marching-squares terraces, corrugated walls with a soil lip, road beds forced flat, and bridges along the road polyline over gorge spans. The post pass reads a multilayer EXR and applies depth fog, height fog, glow, ACES, the grade and a depth-based tilt-shift. Its values are the starting point for #95 and #327.
- The owner's character references (the green goblin, the blue knight, the foe sheet) are kept by the owner and are not in the repo. Never trace them or use them as input to a generator; model from them by eye.
