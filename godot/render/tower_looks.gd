## Finds the saved look of a tower type.
class_name TowerLooks
extends RefCounted

const FILE_NAMES := {
	"ballista": "ballista",
	"catapult": "catapult",
	"frostSpire": "frost_spire",
	"stormSpire": "storm_spire",
}
const FALLBACK_FILE := "ballista"
const DIRECTORY := "res://render/looks/"


## The .tres file name (without extension) for a tower id.
static func file_name_for(type: String) -> String:
	return FILE_NAMES.get(type, FALLBACK_FILE)


## The look of a tower type; an unknown type gets the Ballista look.
static func for_type(type: String) -> TowerLook:
	return load(DIRECTORY + file_name_for(type) + ".tres") as TowerLook
