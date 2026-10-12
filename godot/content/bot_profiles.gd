## The strategies the scripted bot plays, for balance runs (`sim/bot`). Data only.
##
## `build_order`: the tower ids it builds, in turn, cycling when the list ends.
## `call_early`: whether it calls the next wave while foes are still walking, and
## `early_foes_left`: how few foes must be left for it to do so.
extends RefCounted

const PROFILE_IDS: Array[String] = ["spoolOnly", "mortarHeavy", "mix"]

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
	"mix":
	{
		"build_order": ["spoolGuard", "thimbleMortar", "prismSpire", "spoolGuard"],
		"call_early": false,
		"early_foes_left": 0,
	},
}
