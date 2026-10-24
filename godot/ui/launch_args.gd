## The command-line user arguments of a desktop run (`godot --path godot -- --layout-valley
## --seed=7`). Anything else is ignored.
class_name LaunchArgs
extends RefCounted

const LAYOUT_VALLEY := "--layout-valley"
const SEED := "--seed="
const MAX_SEED_LENGTH := 16


## Whether the layout valley is asked for.
static func layout_valley(args: PackedStringArray) -> bool:
	return args.has(LAYOUT_VALLEY)


## The seed asked for with `--seed=N` (the last one wins), or null when there is none or it is
## not a whole number of at most 16 characters.
static func seed_value(args: PackedStringArray) -> Variant:
	var found: Variant = null
	for arg in args:
		if not arg.begins_with(SEED):
			continue
		var text := arg.trim_prefix(SEED)
		found = int(text) if text.is_valid_int() and text.length() <= MAX_SEED_LENGTH else null
	return found
