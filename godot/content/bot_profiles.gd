## The strategies the scripted bot plays, for balance runs (`sim/bot`). Data only.
##
## `build_order`: the tower ids it builds, in turn, cycling when the list ends.
## `call_early`: whether it calls the next wave while foes are still walking, and
## `early_foes_left`: how few foes must be left for it to do so.
## `max_towers` (optional, `MAX_TOWERS` when left out): how many towers it builds before it
## upgrades them; it builds more only once every tower is at the top level.
extends RefCounted

## The towers the bot builds before it upgrades: the most sockets the 16 by 11 board had, so the
## bot plays the bigger valley (24 to 30 sockets, #320) the way it played the smaller board.
const MAX_TOWERS := 15
const PROFILE_IDS: Array[String] = ["spoolOnly", "mortarHeavy", "prismHeavy", "mix", "guardMix"]

const PROFILES := {
	"spoolOnly":
	{
		"build_order": ["spoolGuard"],
		"call_early": false,
		"early_foes_left": 0,
	},
	"mortarHeavy":
	{
		"build_order": ["thimbleMortar", "thimbleMortar", "spoolGuard"],
		"call_early": false,
		"early_foes_left": 0,
	},
	"prismHeavy":
	{
		"build_order": ["prismSpire", "spoolGuard", "prismSpire"],
		"call_early": false,
		"early_foes_left": 0,
	},
	"mix":
	{
		"build_order": ["spoolGuard", "thimbleMortar", "prismSpire", "spoolGuard"],
		"call_early": false,
		"early_foes_left": 0,
	},
	# the mix with a Guard Tent and a Mess Tent for its aura among the damage towers
	# (docs/BARRACKS.md); a build with tents in half its slots starves its economy
	"guardMix":
	{
		"build_order":
		[
			"spoolGuard",
			"thimbleMortar",
			"prismSpire",
			"spoolGuard",
			"guardTent",
			"thimbleMortar",
			"messTent",
			"prismSpire"
		],
		"call_early": false,
		"early_foes_left": 0,
	},
}
