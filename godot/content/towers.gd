## The towers of the GDD's combat slice, as numbers. The GDD gives none, so they
## start from the prototype's table (`src/content/towers.ts`): the Spool Guard is
## its Ballista, the Thimble Mortar its Catapult, and the Prism Spire takes the
## Storm Spire's damage and rate as damage per second. The prototype's Frost Spire
## and Storm Spire have no GDD counterpart and are dropped; the Guard Tent comes
## in Phase 7. Data only; the owner tunes the numbers.
##
## Interim balance (2026-10-12, see `docs/BALANCE.md`): tuned with the scripted bot so
## that a build of only one tower keeps up with the others. Spool Guard damage was
## raised from 9, 15, 26 (the Corrugated Orc's armor is now 6), Thimble Mortar damage
## trimmed from 32, 56, 96 (untrimmed it wins 15 of 16 maps), and the Prism Spire's damage per second raised from 16,
## 33, 65 with its cost cut from 110, 100, 180. Redo it after the Phase 7 content.
##
## Level-indexed stats: index 0 is level 1, index 2 is level 3.
extends RefCounted

const TOWER_IDS: Array[String] = ["spoolGuard", "thimbleMortar", "prismSpire"]

## Per tower: `name`, `damage_type` ("physical", "magic" or "true"), `cost`,
## `damage` (per shot, or per second for a beam), `range` (cells) and, for a
## tower that fires shots, `rate` (shots per second).
## The Thimble Mortar also has `splash` (blast radius, cells). The Prism Spire is
## a continuous beam: `beam` is true and it has no `rate`.
const DEFS := {
	"spoolGuard":
	{
		"name": "Spool Guard",
		"damage_type": "physical",
		"cost": [50, 60, 110],
		"damage": [11, 18, 30],
		"range": [2.3, 2.6, 3.0],
		"rate": [3.0, 3.6, 4.5],
	},
	"thimbleMortar":
	{
		"name": "Thimble Mortar",
		"damage_type": "physical",
		"cost": [90, 90, 160],
		"damage": [29, 51, 88],
		"range": [2.8, 3.1, 3.5],
		"rate": [0.7, 0.8, 0.95],
		"splash": [0.95, 1.15, 1.35],
	},
	"prismSpire":
	{
		"name": "Prism Spire",
		"damage_type": "magic",
		"cost": [100, 90, 160],
		"damage": [36, 72, 140],
		"range": [2.3, 2.6, 2.9],
		"beam": true,
	},
}
