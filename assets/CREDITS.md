# Asset credits

Every file in `godot/assets/` is listed here with its source and licence. CI (`pnpm check:assets`) fails when a file there is missing from this list, when this list names a file that is gone, or when a row does not say CC0 or `Owned by the owner (all rights reserved)` (fonts may also say `SIL OFL 1.1`). Allowed sources: CC0 packs (the licence was confirmed from the licence file inside the downloaded pack) and the owner's own models, which the owner owns and does not dedicate to the public domain (the row says `Owned by the owner (all rights reserved)`; the code stays MIT). Generated models (Meshy) are not used: the owner decided on 2026-10-13 to model every foe in Blender.

## Models

The greybox draws primitives, except the owner's models below. When a model is added, add a row for it here, as a table line that starts with the file path in backticks (path relative to `godot/assets/`, then source, licence and edits).

| File | Source | Licence | Edits |
| --- | --- | --- | --- |
| `models/enemies/scrap_goblin.glb` | Original, the owner (greybox Scrap Goblin, 566 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/corrugated_orc.glb` | Original, the owner (greybox Corrugated Orc, 308 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/cardboard_golem.glb` | Original, the owner (greybox Cardboard Golem, 324 triangles, static) | Owned by the owner (all rights reserved) | drawn by `render/foes_view.gd` |
| `models/enemies/razor_moth.glb` | Original, the owner (greybox Razor Moth, 284 triangles, static) | Owned by the owner (all rights reserved) | used by FoesView for the Ink Shaman |
| `models/enemies/ink_shaman.glb` | Original, the owner (greybox Ink Shaman, 306 triangles, static) | Owned by the owner (all rights reserved) | used by FoesView for the Ink Shaman |
| `models/heroes/knight_of_cardboard.glb` | Original, the owner (greybox Knight of Cardboard, 408 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the hero is not in the game) |
| `models/heroes/camp_cook.glb` | Original, the owner (greybox Camp Cook, 392 triangles, static) | Owned by the owner (all rights reserved) | not used yet (the hero is not in the game) |
| `models/towers/spool_guard.glb` | Original, the owner (greybox Spool Guard, 214 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/thimble_mortar.glb` | Original, the owner (greybox Thimble Mortar, 320 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/prism_spire.glb` | Original, the owner (greybox Prism Spire, 256 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/guard_tent.glb` | Original, the owner (greybox Guard Tent, 68 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/kitchen_mess_tent.glb` | Original, the owner (greybox Kitchen Mess Tent, 184 triangles, static) | Owned by the owner (all rights reserved) | none |
| `models/towers/heartstone.glb` | Original, the owner (papercraft origami Heartstone, 92 triangles, static; `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/overlay_bridge_deck.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/overlay_bridge_rail.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/overlay_glue_puddle.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/overlay_socket_built_2x2.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/overlay_socket_empty_2x2.glb` | Original, the owner (papercraft pencil circle, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/overlay_tape_trap.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/skirt_desk.glb` | Original, the owner (papercraft desk tile, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/skirt_eraser.glb` | Original, the owner (papercraft desk tile with an eraser, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/skirt_pencil.glb` | Original, the owner (papercraft desk tile with a pencil, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/terrain_cardboard_l1.glb` | Original, the owner (papercraft corrugated cardboard rise, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/terrain_foil_river.glb` | Original, the owner (greybox terrain piece) | Owned by the owner (all rights reserved) | none |
| `models/terrain/terrain_lane.glb` | Original, the owner (papercraft cutting mat tile under the tape, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/terrain_mat.glb` | Original, the owner (papercraft cutting mat tile, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/terrain_paperboard_l2.glb` | Original, the owner (papercraft grey board cliff, `assets-src/papercraft/godot_kit.py`) | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/blot_spawn.glb` | Original, the owner (papercraft spilled ink and bottle at a spawn), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_tree_pine.glb` | Original, the owner (papercraft folded pine tree), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_tree_round.glb` | Original, the owner (papercraft folded round tree), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_shrub.glb` | Original, the owner (papercraft folded leaves), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_grass.glb` | Original, the owner (papercraft grass fringe), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_flowers.glb` | Original, the owner (papercraft flowers), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_buttons.glb` | Original, the owner (papercraft buttons), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_pins.glb` | Original, the owner (papercraft push pins), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_glue.glb` | Original, the owner (papercraft PVA glue spill), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `models/terrain/decor_scrap.glb` | Original, the owner (papercraft newspaper scrap), `assets-src/papercraft/godot_kit.py` | Owned by the owner (all rights reserved) | drawn by `render/board.gd` |
| `audio/music/music_tier1_planning.ogg` | Original, the owner (greybox music, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/music/music_tier2_wave.ogg` | Original, the owner (greybox music, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/music/music_tier3_boss.ogg` | Original, the owner (greybox music, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_cardstock_fold.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_glass_chime_prism.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_glass_chime_spell.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_metal_snap.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_paper_tear.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_paper_tear_short.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_scissor_snap.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_stamp_thud_boss_step.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_stamp_ui_confirm.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_thimble_clink.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_twang_spool_guard.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `audio/sfx/sfx_twang_thimble_mortar.ogg` | Original, the owner (greybox sound effect, generated by the owner, converted from wav to ogg) | Owned by the owner (all rights reserved) | wav to ogg (Vorbis q4) |
| `models/ui/messenger_crow.glb` | Original, the owner (greybox Messenger Crow, 438 triangles, static) | Owned by the owner (all rights reserved) | none |

## Textures

Generated with numpy for the papercraft shaders in `render/paper/` (seamless noise and cut marks; `assets-src/papercraft/textures.py`).

| File | Source | Licence | Edits |
| --- | --- | --- | --- |
| `textures/paper/paper_noise.png` | Original, the owner (seamless paper fibre, blotch, speck and crinkle noise) | Owned by the owner (all rights reserved) | read by `render/paper_look.gd` |
| `textures/paper/mat_cuts.png` | Original, the owner (seamless healed cut marks for the cutting mat) | Owned by the owner (all rights reserved) | read by `render/paper_look.gd` |

## Fonts

The HUD's two typefaces. Fonts may be SIL OFL 1.1 as well as CC0 (owner decision, 2026-10-15); the OFL lets a game embed them, and the licence texts are kept in `assets/licenses/`.

| File | Source | Licence | Edits |
| --- | --- | --- | --- |
| `fonts/BricolageGrotesque.ttf` | Bricolage Grotesque, The Bricolage Grotesque Project Authors, from github.com/google/fonts (`ofl/bricolagegrotesque`, variable font) | SIL OFL 1.1 (`assets/licenses/OFL-BricolageGrotesque.txt`) | renamed from `BricolageGrotesque[opsz,wdth,wght].ttf` |
| `fonts/PatrickHand-Regular.ttf` | Patrick Hand, Patrick Wagesreiter, from github.com/google/fonts (`ofl/patrickhand`) | SIL OFL 1.1 (`assets/licenses/OFL-PatrickHand.txt`) | none |

## HUD icons

Drawn as SVG for the papercraft HUD (Claude Design canvas "Papercraft Kingdom Defense · HUD"), made with Claude for the owner like the owner's Blender models.

| File | Source | Licence | Edits |
| --- | --- | --- | --- |
| `icons/auto.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/close.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/coin.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/flag.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/heart.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/menu.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/pause.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/play.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/tower_guard_tent.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/tower_mess_tent.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/tower_prism_spire.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/tower_spool_guard.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |
| `icons/tower_thimble_mortar.svg` | Original, the owner (HUD icon, drawn with Claude) | Owned by the owner (all rights reserved) | none |

## History: assets of the Three.js game

The Three.js game (tag `web-three-final`) shipped these, all removed from the tree with it. They are listed so the credit survives, and any of them that returns needs a row above.

- Kenney [Castle Kit 2.0](https://kenney.nl/assets/castle-kit), [Mini Dungeon 2.0](https://kenney.nl/assets/mini-dungeon) and [Tower Defense Kit 2.1](https://kenney.nl/assets/tower-defense-kit) by Kenney (kenney.nl): CC0 1.0 (`License.txt` in each pack).
- The `scrapline/` towers (Ballista, Catapult, Frost Spire and Storm Spire, three levels each) are original work: the owner generated them with Claude and Blender (`assets-src/blender/towers.py`) and dedicates them to the public domain under CC0 1.0.
