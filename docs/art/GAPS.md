# Asset gaps (Phase 3)

Shortlist of CC0 sources and what each unit still needs. Coverage is an expectation from the pack pages, **not verified**: the models have not been downloaded or opened yet, and licences are taken from the pack pages. Before any asset enters `public/assets/` or `assets-src/`, download the pack, open its licence file and confirm CC0, then add it to `assets/CREDITS.md`.

## Shortlist

| Pack | Author | Why it is on the list | Licence on the pack page | Status |
| --- | --- | --- | --- | --- |
| [Sci-Fi Essentials Kit](https://quaternius.com/packs/scifiessentialskit.html) | Quaternius | Animated robot enemies, textured turrets and guns, tracked vehicles, 65 models, glTF | CC0 | Primary candidate for robots, the Smelter base and tower bases. Download and confirm the licence file. |
| [Ultimate Space Kit](https://sketchfab.com/3d-models/ultimate-space-kit-84c108ff2bcf4d4cbf2adff74a942822) | Quaternius | 90+ models including animated characters and mechs; a source for the Overseer | CC0 | Check the mech models and polygon counts. |
| [LowPoly Robot](https://quaternius.itch.io/lowpoly-robot) | Quaternius | One animated robot (FBX only, 14 animations) | CC0 | Fallback for the Hauler body; needs conversion to glTF. |
| [Tower Defense Kit](https://kenney.nl/assets/tower-defense-kit) | Kenney | Tower and structure pieces, about 160 files | CC0 | Source for tower bases and props. Format list not shown on the page; check after download. |

**Rejected:** [Sci-Fi Turrets Pack](https://sasvel.itch.io/sci-fi-turrets-pack) (sasvel). It ships glb and rigged turrets, but the page states CC BY 4.0, not CC0. Rule: CC0 only unless asked otherwise.

## Gaps per unit

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Skitter | Small robot or drone from Sci-Fi Essentials Kit | Recolour; keep it spindly and small so it reads as the fastest unit. Fallback: the greybox primitive. |
| Hauler | Robot from Sci-Fi Essentials Kit, or LowPoly Robot | Add a cargo frame as a kitbash part. Fallback: primitive. |
| Smelter | Tracked vehicle from Sci-Fi Essentials Kit | Add glowing vents (emissive parts). Fallback: primitive. |
| Overseer | Large mech from Ultimate Space Kit | Add a red sensor core and crown. Only unit allowed skinning. Fallback: primitive. |
| Welder, Rivet Mortar, Mainline Arc | Turret and gun models from Sci-Fi Essentials Kit and Tower Defense Kit | Tint from the palette; Mainline Arc prongs and Quench Coil rings likely built from primitives. |
| Quench Coil | None expected | Primitive rings on a pack pole. |
| Level 2 and 3 parts, level lights | None | Small add-on parts from primitives; emissive pips. |

## Rules

- A unit that is not distinct at zoomed-out view after recolouring gets a different model, not weaker readability.
- Each unit keeps its primitive builder as the fallback behind `src/render/models/index.ts`.
- Check polygon counts against the budget (about 150k triangles with 80 robots and every tower at level 3); decimate in Blender if needed.

## Next

1. Download the three Quaternius packs and the Kenney kit; confirm each licence file; note exact model names for each unit.
2. Update this file with the chosen model per unit and its polygon count.
3. Final reference sheets (Claude Design) follow this list.
