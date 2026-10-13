# Asset credits

Every file in `godot/assets/` is listed here with its source and licence. CI (`pnpm check:assets`) fails when a file there is missing from this list, when this list names a file that is gone, or when a row does not say CC0 or `Owned by the owner (all rights reserved)`. Allowed sources: CC0 packs (the licence was confirmed from the licence file inside the downloaded pack) and the owner's own models, which the owner owns and does not dedicate to the public domain (the row says `Owned by the owner (all rights reserved)`; the code stays MIT). Generated models (Meshy) are not used: the owner decided on 2026-10-13 to model every foe in Blender.

## Models

The greybox draws primitives, except the owner's models below. When a model is added, add a row for it here, as a table line that starts with the file path in backticks (path relative to `godot/assets/`, then source, licence and edits).

| File | Source | Licence | Edits |
| --- | --- | --- | --- |
| `models/enemies/scrap_goblin.glb` | Original, the owner (greybox Scrap Goblin, 566 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/corrugated_orc.glb` | Original, the owner (greybox Corrugated Orc, 308 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/cardboard_golem.glb` | Original, the owner (greybox Cardboard Golem, 324 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/razor_moth.glb` | Original, the owner (greybox Razor Moth, 284 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the foe is not in the game) |
| `models/enemies/ink_shaman.glb` | Original, the owner (greybox Ink Shaman, 306 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the foe is not in the game) |
| `models/heroes/knight_of_cardboard.glb` | Original, the owner (greybox Knight of Cardboard, 408 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the hero is not in the game) |
| `models/heroes/camp_cook.glb` | Original, the owner (greybox Camp Cook, 392 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the hero is not in the game) |
| `models/towers/spool_guard.glb` | Original, the owner (greybox Spool Guard, 214 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/thimble_mortar.glb` | Original, the owner (greybox Thimble Mortar, 320 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/prism_spire.glb` | Original, the owner (greybox Prism Spire, 256 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/guard_tent.glb` | Original, the owner (greybox Guard Tent, 68 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/kitchen_mess_tent.glb` | Original, the owner (greybox Kitchen Mess Tent, 184 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/heartstone.glb` | Original, the owner (greybox Heartstone, 196 triangles, static) | Owned by the owner (all rights reserved) | none |

## History: assets of the Three.js game

The Three.js game (tag `web-three-final`) shipped these, all removed from the tree with it. They are listed so the credit survives, and any of them that returns needs a row above.

- Kenney [Castle Kit 2.0](https://kenney.nl/assets/castle-kit), [Mini Dungeon 2.0](https://kenney.nl/assets/mini-dungeon) and [Tower Defense Kit 2.1](https://kenney.nl/assets/tower-defense-kit) by Kenney (kenney.nl): CC0 1.0 (`License.txt` in each pack).
- The `scrapline/` towers (Ballista, Catapult, Frost Spire and Storm Spire, three levels each) are original work: the owner generated them with Claude and Blender (`assets-src/blender/towers.py`) and dedicates them to the public domain under CC0 1.0.
