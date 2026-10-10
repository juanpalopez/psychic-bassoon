## Tower definitions ported from the 2D prototype's `DEF` table (the
## TypeScript content in `src/content/towers.ts`). Data only.
##
## Level-indexed stats: index 0 is level 1, index 2 is level 3. The ids are
## the stable keys shared with the fixtures.
extends RefCounted

const TOWER_IDS: Array[String] = ["ballista", "catapult", "frostSpire", "stormSpire"]

## Per tower: `name`, `cost`, `damage`, `range`, `rate` (shots per second) and,
## for some, `splash` (Catapult blast radius, cells), `slow` (Frost Spire speed
## reduction, 0..1) and `chain` (Storm Spire number of targets).
const DEFS := {
	"ballista":
	{
		"name": "Ballista",
		"cost": [50, 60, 110],
		"damage": [9, 15, 26],
		"range": [2.3, 2.6, 3.0],
		"rate": [3.0, 3.6, 4.5],
	},
	"catapult":
	{
		"name": "Catapult",
		"cost": [90, 90, 160],
		"damage": [32, 56, 96],
		"range": [2.8, 3.1, 3.5],
		"rate": [0.7, 0.8, 0.95],
		"splash": [0.95, 1.15, 1.35],
	},
	"frostSpire":
	{
		"name": "Frost Spire",
		"cost": [70, 70, 120],
		"damage": [3, 5, 9],
		"range": [1.7, 2.0, 2.4],
		"rate": [1.0, 1.15, 1.35],
		"slow": [0.35, 0.45, 0.55],
	},
	"stormSpire":
	{
		"name": "Storm Spire",
		"cost": [110, 100, 180],
		"damage": [18, 30, 50],
		"range": [2.3, 2.6, 2.9],
		"rate": [0.9, 1.1, 1.3],
		"chain": [3, 4, 6],
	},
}
