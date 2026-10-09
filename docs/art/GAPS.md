# Asset gaps (Phase 3)

Shortlist of CC0 sources and what each unit still needs. Two packs were **downloaded and opened** (see Verified); the rest is still an expectation from pack pages. Before any asset enters `public/assets/`, record it in `assets/CREDITS.md` with its source and licence.

## Verified (downloaded and opened)

| Pack | Licence file | What is really in it | Verdict |
| --- | --- | --- | --- |
| Quaternius **Sci-Fi Essentials Kit, free "Standard" version** (itch.io, 159 MB zip) | `License_Standard.txt`: CC0 1.0 Universal | Only 3 enemies (Eye Drone 3.5k triangles, Quad Shell 7.5k, Trilobite 8.3k; all skinned, 6 to 9 animations each, 1 to 3 MB PBR textures), 8 guns, about 40 props (crates, shelves, satellite dish, planets). **No turrets and no tracked vehicles**: the page's "turrets and tracked vehicles" belong to the paid Pro version, which is not CC0-free. | Usable as kitbash and reference. Eye Drone is a possible Skitter; Quad Shell and Trilobite could become Hauler or Smelter bases. Far over budget as shipped (about 6k triangles each against about 1k per robot at 80 robots), skinned (rule: no skinning except the Overseer), so each must be stripped to a static pose, decimated and re-textured first. |
| Kenney **Tower Defense Kit 2.1** (160 GLB files) | `License.txt`: CC0 | Fantasy towers (stone, round and square, with crystals), catapult, ballista, cannon, turret weapon parts, UFO enemies, terrain tiles. Single colour-swatch material, about 40 to 60 KB per model. | Style clashes with a robot factory. Useful only as turret weapon parts (cannon, turret) after recolour. Not a base for the towers. |

**Rejected:** [Sci-Fi Turrets Pack](https://sasvel.itch.io/sci-fi-turrets-pack) (sasvel). Rigged turrets in glb, but the page states CC BY 4.0, not CC0. Rule: CC0 only unless asked otherwise.

**Not found / not checked:** Quaternius Ultimate Space Kit (not on itch under that name; not downloaded), LowPoly Robot (FBX only, one humanoid, not downloaded).

## Consequence for the plan

The free packs cover little: three alien-looking drones and no towers. Towers, the Overseer and most level parts will be primitives or kitbashed unless a better CC0 source turns up. A shared palette texture on improved primitives (the Phase 2 greybox, refined) is a valid fallback and costs nothing in licences or size.

## Gaps per unit

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Skitter | Eye Drone from the free Sci-Fi Essentials Kit | Strip skin, decimate to about 1k triangles, recolour. Fallback: the greybox primitive. |
| Hauler | Quad Shell or Trilobite from the free kit (or a primitive) | Static pose, decimate, add a cargo frame. Fallback: primitive. |
| Smelter | None in the free kit (tracked vehicles are Pro only) | Keep the primitive crawler and add emissive vents. |
| Overseer | Trilobite (largest) as a kitbash base, or primitive | Add a red sensor core and crown. Only unit allowed skinning. Fallback: primitive. |
| Welder, Rivet Mortar, Mainline Arc | Free-kit guns (Rifle, Sniper) as barrels; Kenney cannon and turret parts | Primitive bases tinted from the palette; pack parts only as barrels. |
| Quench Coil | None expected | Primitive rings on a pack pole. |
| Level 2 and 3 parts, level lights | None | Small add-on parts from primitives; emissive pips. |

## Rules

- A unit that is not distinct at zoomed-out view after recolouring gets a different model, not weaker readability.
- Each unit keeps its primitive builder as the fallback behind `src/render/models/index.ts`.
- Check polygon counts against the budget (about 150k triangles with 80 robots and every tower at level 3); decimate in Blender if needed.

## Next

1. Decide the direction (see ticket #90): kitbash the three free drones, or refine the primitives with a shared palette texture.
2. If kitbashing: build the conversion step (strip skin, decimate, compress) in the GLB pipeline ticket and record each file in `assets/CREDITS.md`.
3. Final reference sheets (Claude Design) follow the chosen direction.
