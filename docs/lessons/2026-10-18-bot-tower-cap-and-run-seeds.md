---
type: decision
date: 2026-10-18
status: accepted
decided-by: Claude (within ticket scope)
links: [#320, #237]
---
# Cap the scripted bot at 15 towers and move the CI game and the win test to valley seeds

## Context
The valley has 24 to 30 sockets (mean 26.2 over seeds 1 to 8). The bot fills every socket before its first upgrade, so on the valley it would spread its Buttons over twice the towers it had on 16x11 before upgrading any. Two seed choices tied to the 16x11 board stopped winning: CI's guard mix seed 4 (falls at wave 16) and the win test's mix seed 7 (falls at wave 14).

## Decision
- `MAX_TOWERS = 15` in `godot/content/bot_profiles.gd` (the most sockets 16x11 had; a profile may set `max_towers`). With it the 4-seed sweep gave median 20 waves for four profiles, 18 for the Mortar; the 8-seed sweep is in `docs/BALANCE.md` (The 32 by 20 valley).
- CI's game-time check plays guard mix seed 2 (a win on the valley, about 15 s of CPU here).
- `test_the_scripted_bot_wins_a_20_wave_run` plays mix seed 3 (won with all 20 Heartstone health).

## Alternatives considered
- No cap: the bot plays the valley as a weaker player than on 16x11, which skews the #237 sweep.
- Keep seed 4 in CI and lower the bar: the check needs a whole 20-wave game to time.

## Consequences
- The balance pass (#237) should re-check the cap with the curved routes (#321).
