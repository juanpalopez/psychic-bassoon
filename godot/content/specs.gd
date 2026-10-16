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
##
## Cryo-Origami Spire (Prism Spire, Spec A): Frostbite adds `bonus` (a share) to the damage
## physical towers deal to a slowed or frozen foe inside the spire's reach (the strongest
## bonus applies, they do not add up); Flash Freeze freezes every foe in reach for `seconds`.
## Blot Singularity (Spec B): Corrosive Light strips `per_second` of a foe's armor each
## second its beam burns it, up to `max` (the strip stays on the foe); Ink Vortex opens a
## well for `seconds` at the target that pulls foes within `radius` cells of its centre along
## the main road at `pull` cells a second (foes of the second spawn source too, once they have
## joined it). Foes that are `heavy`, held by a guard or flying are
## not pulled. A well stays open if its tower is sold.
##
## Paper-Plane Aviary (Spool Guard, Spec B): High Recon adds `bonus` (a share) to the reach of
## every other tower whose block lies within `gap` cells of the Aviary's (the strongest bonus
## applies, they do not add up); Squadron Launch sends `planes` planes over everything within the
## Aviary's reach for `seconds`: every `every` seconds each plane drops a bomb of `damage` (a
## `splash` blast) on a different foe, the one furthest along the road first (a support foe is
## not preferred), flyers included.
##
## Cardboard Knights (Guard Tent, Spec A): Corrugated Plating throws back `share` of every blow that
## lands on a guard as true damage to the attacker; Shield Wall multiplies the armor of the tent's
## guards by `armor_mult` for `seconds` (the GDD's knockback immunity does nothing: foes have no
## knockback). Scissor Rogues (Spec B): Paper Cuts slows a foe a guard hits by `slow` (a share) per
## hit, up to `max_stacks`, and the cuts wear off `seconds` after the last hit; Precision Snipe
## strikes the ground foe with the most hp in the tent's reach for `damage` true damage.
##
## Glitter Cannon (Thimble Mortar, Spec A): Shrapnel Spread adds `bonus` (a share) to the blast
## radius; Confetti Burst fires a shell at the target that does `damage` to every foe within
## `radius` cells and blinds them for `seconds`: a blinded foe misses `blind` (a share) of its
## melee blows (counted, never random: every blow adds the share to a tally and a whole tally is
## a miss). Sticky Glue Mortar (Spec B): PVA Deluge slows every foe within `radius` cells of the
## target by `slow` (a share) for `seconds`; Lingering Residue leaves a pool where each shell
## lands, as wide as the blast, that slows ground foes by `slow` for `seconds`.
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
		{
			"id": "paperPlaneAviary",
			"name": "Paper-Plane Aviary",
			"cost": 140,
			"card":
			"Paper planes patrol the road and rain dart bombs; adjacent towers see further.",
			"passive": {"kind": "recon", "bonus": 0.2, "gap": 1.0},
			"active":
			{
				"kind": "squadron",
				"name": "Squadron Launch",
				"cooldown": 28.0,
				"seconds": 10.0,
				"every": 1.0,
				"planes": 3,
				"damage": 18.0,
				"splash": 0.6,
			},
		},
	],
	"guardTent":
	[
		{
			"id": "cardboardKnights",
			"name": "Cardboard Knights",
			"cost": 150,
			"card": "Armored guards that throw part of every blow back at the attacker.",
			"passive": {"kind": "plating", "share": 0.15},
			"active":
			{
				"kind": "shield_wall",
				"name": "Shield Wall",
				"cooldown": 30.0,
				"seconds": 8.0,
				"armor_mult": 2.0
			},
		},
		{
			"id": "scissorRogues",
			"name": "Scissor Rogues",
			"cost": 150,
			"card":
			"Quick blades that slow whoever they cut, and a leap that finishes the toughest foe.",
			"passive": {"kind": "paper_cuts", "slow": 0.1, "max_stacks": 3, "seconds": 4.0},
			"active":
			{
				"kind": "precision_snipe",
				"name": "Precision Snipe",
				"cooldown": 20.0,
				"damage": 200.0
			},
		},
	],
	"prismSpire":
	[
		{
			"id": "cryoOrigamiSpire",
			"name": "Cryo-Origami Spire",
			"cost": 160,
			"card":
			"A cold burst sets a whole crowd in paraffin wax; the frozen take more from every shot.",
			"passive": {"kind": "frostbite", "bonus": 0.2},
			"active":
			{"kind": "flash_freeze", "name": "Flash Freeze", "cooldown": 25.0, "seconds": 3.0},
		},
		{
			"id": "blotSingularity",
			"name": "Blot Singularity",
			"cost": 160,
			"card":
			"A spreading ink blot drags the light ones into a heap and eats the armor off whoever it burns.",
			"passive": {"kind": "corrode", "per_second": 0.02, "max": 0.5},
			"active":
			{
				"kind": "ink_vortex",
				"name": "Ink Vortex",
				"cooldown": 30.0,
				"seconds": 5.0,
				"radius": 1.5,
				"pull": 1.2,
			},
		},
	],
	"thimbleMortar":
	[
		{
			"id": "glitterCannon",
			"name": "Glitter Cannon",
			"cost": 160,
			"card": "A wider blast, and a shell of confetti that blinds a whole crowd.",
			"passive": {"kind": "splash_bonus", "bonus": 0.35},
			"active":
			{
				"kind": "confetti_burst",
				"name": "Confetti Burst",
				"cooldown": 22.0,
				"radius": 2.0,
				"damage": 60.0,
				"blind": 0.4,
				"seconds": 6.0,
			},
		},
		{
			"id": "stickyGlueMortar",
			"name": "Sticky Glue Mortar",
			"cost": 160,
			"card": "Shells leave sticky pools, and a deluge of PVA glue pins a whole crowd.",
			"passive": {"kind": "residue", "slow": 0.35, "seconds": 4.0},
			"active":
			{
				"kind": "pva_deluge",
				"name": "PVA Deluge",
				"cooldown": 24.0,
				"radius": 2.0,
				"slow": 0.7,
				"seconds": 6.0,
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
