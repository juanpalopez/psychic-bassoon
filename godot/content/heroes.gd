## The heroes the player moves across the valley (GDD section 6, `docs/UNIT_ROSTER.md` H1; #275).
## The GDD gives no numbers, so the Knight starts from the level-3 guard of the Guard Tent
## (owner, 2026-10-22, #450) and is tuned later with headless runs. Data only.
extends RefCounted

const KNIGHT := "knightOfCardboard"

## The hero every run on the game board starts with (owner, 2026-10-22).
const START_HERO := KNIGHT

## How far past the two bodies a hero reaches a foe to hold it, and a foe it broke off from
## reaches the hero, in cells.
const REACH := 0.5

## Per hero: `name`, `hp`, `armor`, `damage` (per blow), `interval` (seconds between blows),
## `radius` (body, in cells), `speed` (cells per second) and `respawn` (seconds before a fallen
## hero stands again at the Heartstone), `rally_cry` (the passive aura: towers and guards within
## `radius` cells of the standing hero get `attack_speed` and `regen`, both shares; the hero's
## aura does not add to itself, and it adds to a Kitchen Mess Tent's) and `blade_whirl` (the
## active: `damage` physical to every ground foe within `radius` cells of the hero's edge, then
## `cooldown` seconds before the next). Interim numbers, tuned later with headless runs (#452).
const DEFS := {
	KNIGHT:
	{
		"name": "Knight of Cardboard",
		"hp": 320.0,
		"armor": 4,
		"damage": 48.0,
		"interval": 1.0,
		"radius": 0.2,
		"speed": 1.5,
		"respawn": 15.0,
		"rally_cry": {"radius": 3.0, "attack_speed": 0.15, "regen": 0.1},
		"blade_whirl": {"radius": 1.0, "damage": 80.0, "cooldown": 15.0},
	},
}
