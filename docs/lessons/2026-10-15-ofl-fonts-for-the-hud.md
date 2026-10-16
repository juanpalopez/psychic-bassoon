---
type: decision
date: 2026-10-15
status: accepted
decided-by: owner on Claude's proposal
links: [#282]
---
# Allow SIL OFL 1.1 fonts in godot/assets, for fonts only

## Context
The papercraft HUD design uses Bricolage Grotesque and Patrick Hand. Both are SIL OFL 1.1, but the asset rule and `scripts/check-assets.mjs` accepted only CC0 or the owner's own files.

## Decision
Fonts under `godot/assets/fonts/` may be SIL OFL 1.1: the credits row says `SIL OFL 1.1` and the licence text lives in `assets/licenses/`. The check accepts OFL only for `fonts/` paths; models, audio and icons stay CC0 or owned. Carried by CLAUDE.md (Assets), `assets/CREDITS.md` and the check.

## Alternatives considered
- Keep Godot's built-in font: no licence change, but the HUD loses its handmade look.
- A CC0 face: none found that fits the papercraft style.

## Consequences
- The OFL asks that the fonts are not sold on their own and keep their notice; shipping them inside the game is allowed.
- Reversing it means swapping the Theme's fonts in `godot/tools/build_hud_theme.gd`.
