---
type: decision
date: 2026-10-15
status: accepted
decided-by: owner
links: [#282]
---
# Offer Auto start: the next wave starts by itself after a cleared wave

## Context
The owner wants to play without tapping Start wave every round. The GDD's loop has the player start a wave or let a timer run out; the game had no timer.

## Decision
An Auto switch sits next to Start wave. With it on, the HUD counts down `AUTO_WAVE_SECONDS` (3 s of game time, so it holds while paused and runs faster at 2x and 3x) once a wave is cleared, shows it on the button ("Wave 5 in 3"), then sends the normal launch command. It never calls a wave while foes are on the board, so the early-call bonus stays a choice. It lives in `godot/ui/auto_wave.gd`; the sim is unchanged. Recorded in the GDD (section 2, screen layout).

## Alternatives considered
- Auto-call waves early for the bonus: rewards idling and breaks the economy.
- A sim-side timer: changes replays and goldens for a HUD convenience.

## Consequences
- The switch resets with the page; remembering it between visits is a follow-up.
