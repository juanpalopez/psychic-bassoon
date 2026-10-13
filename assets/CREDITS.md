# Asset credits

Every file in `godot/assets/` is listed here with its source and licence. CI (`pnpm check:assets`) fails when a file there is missing from this list, when this list names a file that is gone, or when a row does not say CC0 or `Owned by the owner (all rights reserved)`. Allowed sources: CC0 packs (the licence was confirmed from the licence file inside the downloaded pack) and the owner's own models, which the owner owns and does not dedicate to the public domain (the row says `Owned by the owner (all rights reserved)`; the code stays MIT). Generated models (Meshy) are not used: the owner decided on 2026-10-13 to model every foe in Blender.

## Models

`godot/assets/` is empty for now: the Godot greybox draws primitives. When a model is added, add a row for it here, as a table line that starts with the file path in backticks (path relative to `godot/assets/`, then source, licence and edits).

## History: assets of the Three.js game

The Three.js game (tag `web-three-final`) shipped these, all removed from the tree with it. They are listed so the credit survives, and any of them that returns needs a row above.

- Kenney [Castle Kit 2.0](https://kenney.nl/assets/castle-kit), [Mini Dungeon 2.0](https://kenney.nl/assets/mini-dungeon) and [Tower Defense Kit 2.1](https://kenney.nl/assets/tower-defense-kit) by Kenney (kenney.nl): CC0 1.0 (`License.txt` in each pack).
- The `scrapline/` towers (Ballista, Catapult, Frost Spire and Storm Spire, three levels each) are original work: the owner generated them with Claude and Blender (`assets-src/blender/towers.py`) and dedicates them to the public domain under CC0 1.0.
