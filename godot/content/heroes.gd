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
## hero stands again at the Heartstone).
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
	},
}
