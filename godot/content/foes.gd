## The foes the GDD's ground roster starts with, as numbers. The GDD gives none,
## so they start from the prototype's table (`web-three-final:src/content/enemies.ts`): the
## Scrap Goblin is the Scamp (swarm), the Corrugated Orc the Ironclad (armored)
## and the Cardboard Golem the Warlord (boss). The prototype's mid-tier Raider has
## no counterpart in the GDD and is dropped. Flying (Razor Moth) and support (Ink
## Shaman) foes arrive in Phase 7. Data only. The Corrugated Orc's armor is 6 (the
## prototype's Ironclad had 4): see the interim balance in `docs/BALANCE.md`.
extends RefCounted

const FOE_IDS: Array[String] = ["scrapGoblin", "corrugatedOrc", "cardboardGolem"]

## Per foe: `name`, `hp`, `speed` (cells per second), `reward` (Buttons for a kill),
## `armor` (cuts physical damage), `resist` (cuts magic damage; no foe has any yet),
## `radius` (cells), `leak` (Heartstone health lost when it gets
## through) and, for a fight with a guard (`docs/BARRACKS.md`), `attack_damage`
## per blow, `attack_interval` (seconds between blows) and `blockable` (whether a
## guard can stop it; the Golem is not blockable). The Golem also names what it
## splits into when destroyed: `splits_into`, `split_count` of them,
## `split_spacing` cells apart along the route, behind it.
const DEFS := {
	"scrapGoblin":
	{
		"name": "Scrap Goblin",
		"hp": 20,
		"speed": 1.6,
		"reward": 4,
		"armor": 0,
		"resist": 0,
		"radius": 0.24,
		"leak": 1,
		"attack_damage": 3,
		"attack_interval": 0.8,
		"blockable": true,
	},
	"corrugatedOrc":
	{
		"name": "Corrugated Orc",
		"hp": 130,
		"speed": 0.57,
		"reward": 13,
		"armor": 6,
		"resist": 0,
		"radius": 0.38,
		"leak": 2,
		"attack_damage": 14,
		"attack_interval": 1.6,
		"blockable": true,
	},
	"cardboardGolem":
	{
		"name": "Cardboard Golem",
		"hp": 850,
		"speed": 0.42,
		"reward": 110,
		"armor": 6,
		"resist": 0,
		"radius": 0.5,
		"leak": 6,
		"attack_damage": 40,
		"attack_interval": 2.0,
		"blockable": false,
		"splits_into": "scrapGoblin",
		"split_count": 4,
		"split_spacing": 0.4,
	},
}
