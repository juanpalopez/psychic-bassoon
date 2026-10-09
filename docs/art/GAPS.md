# Asset gaps (Phase 3)

Shortlist of CC0 sources and what each unit still needs. Two packs were **downloaded and opened** (see Verified); the rest is still an expectation from pack pages. Before any asset enters `public/assets/`, record it in `assets/CREDITS.md` with its source and licence.

## Verified (downloaded and opened)

| Pack | Licence file | What is really in it | Verdict |
| --- | --- | --- | --- |
| Quaternius **Sci-Fi Essentials Kit, free "Standard" version** (itch.io, 159 MB zip) | `License_Standard.txt`: CC0 1.0 Universal | Only 3 enemies (Eye Drone 3.5k triangles, Quad Shell 7.5k, Trilobite 8.3k; all skinned, 6 to 9 animations each, 1 to 3 MB PBR textures), 8 guns, about 40 props (crates, shelves, satellite dish, planets). **No turrets and no tracked vehicles**: the page's "turrets and tracked vehicles" belong to the paid Pro version, which is not CC0-free. | Usable as kitbash and reference. Eye Drone is a possible Skitter; Quad Shell and Trilobite could become Hauler or Smelter bases. Far over budget as shipped (about 6k triangles each against about 1k per robot at 80 robots), skinned (rule: no skinning except the Overseer), so each must be stripped to a static pose, decimated and re-textured first. |
| Kenney **Tower Defense Kit 2.1** (160 GLB files) | `License.txt`: CC0 | Fantasy towers (stone, round and square, with crystals), catapult, ballista, cannon, turret weapon parts, UFO enemies, terrain tiles. Single colour-swatch material, about 40 to 60 KB per model. | Style clashes with a robot factory. Useful only as turret weapon parts (cannon, turret) after recolour. Not a base for the towers. |

**Rejected:** [Sci-Fi Turrets Pack](https://sasvel.itch.io/sci-fi-turrets-pack) (sasvel). Rigged turrets in glb, but the page states CC BY 4.0, not CC0. Rule: CC0 only unless asked otherwise.

**Not found / not checked:** Quaternius Ultimate Space Kit (not on itch under that name; not downloaded), LowPoly Robot (FBX only, one humanoid, not downloaded).

## Direction: medieval (owner decision)

The lore is now medieval (see `docs/PLAN.md` → Lore), which makes the Kenney Tower Defense Kit the **primary** source instead of a poor fit:

- **Towers:** stone tower pieces, ballista, catapult and cannon weapons, and crystals cover the Ballista, Catapult, Frost Spire and Storm Spire. Recolour crystals to violet and yellow.
- **Terrain:** grass and dirt road tiles, spawn and end tiles, trees, rocks, fences and snow variants for later chapters replace the primitive plates and belt.
- **Heartstone (the Core):** crystal pieces.

**Foes are still the gap.** Kenney's kit only has UFO enemies, and the Quaternius free kit has alien drones, neither of which is medieval. Foes need a second CC0 source (candidates to check: Quaternius fantasy and monster packs, Kenney Castle Kit, Fantasy Town Kit and Mini Dungeon). None is chosen or downloaded. Until then, foes stay as refined primitives, with the Warlord as the only skinned unit.

The Quaternius Sci-Fi Essentials Kit is no longer a source; it stays here only as a record of what was checked.

## Gaps per unit

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Scamp, Raider, Ironclad | A fantasy or monster pack (to be found) | Recolour and decimate. Fallback: the greybox primitives, refined. |
| Warlord | Same pack, a large champion | Add a red glowing core and an iron crown. Only unit allowed skinning. Fallback: primitive. |
| Ballista, Catapult | Kenney `weapon-ballista`, `weapon-catapult` on a tower base | Recolour; add level add-ons (extra bolts, bigger arm). |
| Frost Spire, Storm Spire | Kenney `tower-round-crystals` and crystal details | Violet and yellow crystals; add rings or prongs per level. |
| Terrain and road | Kenney tiles | Needs a tile picker from the sim map; a decorative layer only. |
| Level 2 and 3 parts, level lights | None | Small add-on parts from primitives; emissive pips. |

## Rules

- A unit that is not distinct at zoomed-out view after recolouring gets a different model, not weaker readability.
- Each unit keeps its primitive builder as the fallback behind `src/render/models/index.ts`.
- Check polygon counts against the budget (about 150k triangles with 80 foes and every tower at level 3); decimate if needed.

## Next

1. Find and verify a CC0 source for foes (download, open the licence file, count triangles and skins).
2. Build the conversion step (strip skin, decimate, compress) in the GLB pipeline ticket (#92); record each file in `assets/CREDITS.md`.
3. Rename units in code to the medieval names (separate PR), then swap models one at a time.
