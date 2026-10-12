## The foes the GDD's ground roster starts with, as numbers. The GDD gives none,
## so they start from the prototype's table (`src/content/enemies.ts`): the
## Scrap Goblin is the Scamp (swarm), the Corrugated Orc the Ironclad (armored)
## and the Cardboard Golem the Warlord (boss). The prototype's mid-tier Raider has
## no counterpart in the GDD and is dropped. Flying (Razor Moth) and support (Ink
## Shaman) foes arrive in Phase 7. Data only.
extends RefCounted

const FOE_IDS: Array[String] = ["scrapGoblin", "corrugatedOrc", "cardboardGolem"]

## Per foe: `name`, `hp`, `speed` (cells per second), `reward` (Buttons for a kill),
## `armor` (cuts physical damage), `resist` (cuts magic damage; no foe has any yet),
## `radius` (cells) and `leak` (Heartstone health lost when it gets
## through). The Golem also names what it splits into when destroyed: `splits_into`,
## `split_count` of them, `split_spacing` cells apart along the route, behind it.
const DEFS := {
	"scrapGoblin":
	{
		"name": "Scrap Goblin",
		"hp": 20,
		"speed": 1.9,
		"reward": 4,
		"armor": 0,
		"resist": 0,
		"radius": 0.24,
		"leak": 1
	},
	"corrugatedOrc":
	{
		"name": "Corrugated Orc",
		"hp": 130,
		"speed": 0.68,
		"reward": 13,
		"armor": 4,
		"resist": 0,
		"radius": 0.38,
		"leak": 2
	},
	"cardboardGolem":
	{
		"name": "Cardboard Golem",
		"hp": 850,
		"speed": 0.5,
		"reward": 110,
		"armor": 6,
		"resist": 0,
		"radius": 0.5,
		"leak": 6,
		"splits_into": "scrapGoblin",
		"split_count": 4,
		"split_spacing": 0.4,
	},
}
