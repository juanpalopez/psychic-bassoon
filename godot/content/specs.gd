## Tier 4: the specialisations a level 3 tower can choose between (the GDD's
## "Spec A" and "Spec B"). Data only: the sim reads the numbers, and the lore
## and display names live here.
##
## Per spec: `id` (a stable key), `name`, `cost` (Buttons), `card` (a line for the
## spec card), `passive` and `active`. Each has a `kind` the sim maps to its
## handler plus the numbers that kind needs; an active also has a `cooldown` in
## seconds. A tower with no entry here has no tier 4 yet.
##
## Crossbow Ballista (Spool Guard, Spec A): Armor Piercing ignores `share` of an
## armored foe's armor; Heavy Skewer sends a bolt along the line from the tower to
## its target, through up to `max_hits` foes within `width` cells of the line (plus
## the foe's own radius), nearest first, for `damage` each, and leaves a bleed of
## `bleed_dps` true damage a second for `bleed_seconds`.
const DEFS := {
	"spoolGuard":
	[
		{
			"id": "crossbowBallista",
			"name": "Crossbow Ballista",
			"cost": 140,
			"card": "A heavy bolt pins a whole column of foes and leaves them bleeding.",
			"passive": {"kind": "armor_ignore", "share": 0.4},
			"active":
			{
				"kind": "skewer",
				"name": "Heavy Skewer",
				"cooldown": 18.0,
				"damage": 120.0,
				"max_hits": 5,
				"width": 0.3,
				"bleed_dps": 8.0,
				"bleed_seconds": 4.0,
			},
		},
	],
}


## The specs a tower type can choose between (empty when it has none yet).
static func for_tower(tower_type: String) -> Array:
	return DEFS.get(tower_type, [])


## The spec named `spec_id` of that tower type, or an empty dictionary.
static func find(tower_type: String, spec_id: String) -> Dictionary:
	for spec in for_tower(tower_type):
		if spec.id == spec_id:
			return spec
	return {}
