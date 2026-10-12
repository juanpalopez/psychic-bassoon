## The command line of `tools/balance_run.gd`, checked: a mistyped option is an
## error with a message, not a quiet run of the wrong inputs.
class_name BalanceArgs
extends RefCounted

const PROFILES := preload("res://content/bot_profiles.gd")
const DEFAULT_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const DEFAULT_WAVES := 20


## What the options say: `seeds`, `profiles`, `waves`, `detail`, and `error`, which
## is empty when every argument was understood.
static func parse(args: PackedStringArray) -> Dictionary:
	var out := {
		"seeds": DEFAULT_SEEDS.duplicate(),
		"profiles": PROFILES.PROFILE_IDS.duplicate(),
		"waves": DEFAULT_WAVES,
		"detail": false,
		"error": "",
	}
	for arg in args:
		if arg.begins_with("--seeds="):
			var seeds: Array[int] = []
			for part in arg.trim_prefix("--seeds=").split(","):
				if not part.is_valid_int():
					return _bad(out, arg, "a seed must be a whole number")
				if seeds.has(int(part)):
					return _bad(out, arg, "seed %s is listed twice" % part)
				seeds.append(int(part))
			out.seeds = seeds
		elif arg.begins_with("--profiles="):
			var ids: Array[String] = []
			for part in arg.trim_prefix("--profiles=").split(","):
				if not PROFILES.PROFILES.has(part):
					return _bad(out, arg, "unknown profile %s" % part)
				if ids.has(part):
					return _bad(out, arg, "profile %s is listed twice" % part)
				ids.append(part)
			out.profiles = ids
		elif arg.begins_with("--waves="):
			var text := arg.trim_prefix("--waves=")
			if not text.is_valid_int() or int(text) < 1:
				return _bad(out, arg, "waves must be a whole number of at least 1")
			out.waves = int(text)
		elif arg == "--detail":
			out.detail = true
		else:
			return _bad(out, arg, "unknown option")
	return out


static func usage() -> String:
	return (
		"usage: godot --headless --path godot -s tools/balance_run.gd -- "
		+ "[--seeds=1,2,3] [--profiles=%s] [--waves=20] [--detail]" % "|".join(PROFILES.PROFILE_IDS)
	)


static func _bad(out: Dictionary, arg: String, reason: String) -> Dictionary:
	out.error = "%s: %s" % [arg, reason]
	return out
