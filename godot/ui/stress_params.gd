## The page parameters of the phone check: `?stress=80` keeps that many foes walking and
## `?fps` shows the fps overlay. Anything else is ignored.
class_name StressParams
extends RefCounted

const MAX_FOES := 300


## The foe count asked for, 0 when the value is missing or is not a plain whole number.
static func foes(value: Variant) -> int:
	if not value is String:
		return 0
	var text: String = value
	if not text.is_valid_int() or text.length() > 6 or text.begins_with("+"):
		return 0
	return clampi(int(text), 0, MAX_FOES)


## Whether the overlay is on: the parameter is there (`?fps`) and does not say 0.
static func fps_on(value: Variant) -> bool:
	return value is String and value != "0"
