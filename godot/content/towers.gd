## The towers of the GDD's combat slice, as numbers. The GDD gives none, so they
## start from the prototype's table (`web-three-final:src/content/towers.ts`): the Spool Guard is
## its Ballista, the Thimble Mortar its Catapult, and the Prism Spire takes the
## Storm Spire's damage and rate as damage per second. The prototype's Frost Spire
## and Storm Spire have no GDD counterpart and are dropped; the Guard Tent comes
## in Phase 7. Data only; the owner tunes the numbers.
##
## Interim balance (2026-10-12, see `docs/BALANCE.md`): tuned with the scripted bot so
## that a build of only one tower keeps up with the others. Spool Guard damage was
## raised from 9, 15, 26 (the Corrugated Orc's armor is now 6), Thimble Mortar damage
## trimmed from 32, 56, 96 (untrimmed it wins 14 of 16 maps), and the Prism Spire's
## damage per second raised from 16, 33, 65 with its cost cut from 110, 100, 180.
## Final pass for Phase 4 (2026-10-13, #203): the Mortar is trimmed again to 27, 48, 83 so
## that no strategy wins with ease. Waves in Fibonacci groups (2026-10-13, #240): waves are
## 40% bigger, foes 12% faster and splash matters far more, so the Mortar went down to 22,
## 40, 68 and the Spool Guard and the Prism Spire up to 13, 21, 35 and 42, 84, 163 damage.
## Redo it after the Phase 7 content.
##
## The Guard Tent (`docs/BARRACKS.md`) is a tower that does not shoot: `guards` is
## true, and it owns `guard_count` guards (`guard_hp`, `guard_armor`, `guard_damage`
## per blow, `guard_interval` seconds between blows, `respawn` seconds after a fall,
## `regen` hp a second out of a fight), `guard_spacing` cells apart with a body
## `guard_radius` wide. `range` is the reach the player sees; the guards post at the
## point of the road nearest the tent (a socket is always within the block touch
## distance of it, see `map_rules.gd`). Interim numbers.
##
## The Kitchen Mess Tent is a `support` tower: it does not shoot and has no damage. Its
## `range` is the radius of its aura, in cells from the middle of its block; every
## guard posted inside it gets `guard_speed_bonus` (a share more blows) and
## `guard_regen_bonus` (hp a second more out of a fight). Only the strongest aura
## applies to a guard. Interim numbers (`docs/BARRACKS.md`). The build menu follows
## the order of `TOWER_IDS`.
##
## Level-indexed stats: index 0 is level 1, index 2 is level 3.
extends RefCounted

const TOWER_IDS: Array[String] = [
	"spoolGuard", "thimbleMortar", "prismSpire", "guardTent", "messTent"
]

## Per tower: `name`, `damage_type` ("physical", "magic" or "true"), `cost`,
## `damage` (per shot, or per second for a beam), `range` (cells) and, for a
## tower that fires shots, `rate` (shots per second).
## A tower with `anti_air` can hit flying foes (the Spool Guard and the Prism Spire); the Thimble
## Mortar's shells and a guard's blows cannot.
## The Thimble Mortar also has `splash` (blast radius, cells). The Prism Spire is
## a continuous beam: `beam` is true and it has no `rate`.
const DEFS := {
	"spoolGuard":
	{
		"name": "Spool Guard",
		"damage_type": "physical",
		"cost": [50, 60, 110],
		"damage": [12, 20, 33],
		"range": [2.3, 2.6, 3.0],
		"rate": [3.0, 3.6, 4.5],
		"anti_air": true,
	},
	"thimbleMortar":
	{
		"name": "Thimble Mortar",
		"damage_type": "physical",
		"cost": [90, 90, 160],
		"damage": [19, 34, 58],
		"range": [2.8, 3.1, 3.5],
		"rate": [0.7, 0.8, 0.95],
		"splash": [0.95, 1.15, 1.35],
	},
	"prismSpire":
	{
		"name": "Prism Spire",
		"damage_type": "magic",
		"cost": [100, 90, 160],
		"damage": [34, 68, 132],
		"range": [2.3, 2.6, 2.9],
		"beam": true,
		"anti_air": true,
	},
	"guardTent":
	{
		"name": "Guard Tent",
		"damage_type": "physical",
		"guards": true,
		"cost": [55, 65, 110],
		"range": [1.9, 2.2, 2.5],
		"guard_count": 2,
		"guard_spacing": 0.5,
		"guard_radius": 0.2,
		"guard_hp": [120, 200, 320],
		"guard_armor": [0, 2, 4],
		"guard_damage": [16, 28, 48],
		"guard_interval": [1.0, 1.0, 1.0],
		"respawn": [6, 5, 4],
		"regen": [1.0, 1.5, 2.0],
	},
	"messTent":
	{
		"name": "Kitchen Mess Tent",
		"support": true,
		"cost": [100, 100, 160],
		"range": [3.0, 3.3, 3.6],
		"guard_speed_bonus": [0.12, 0.18, 0.25],
		"guard_regen_bonus": [2.0, 3.0, 4.0],
	},
}
