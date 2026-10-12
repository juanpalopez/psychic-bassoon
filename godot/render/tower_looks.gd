## Finds the saved look of a tower type.
class_name TowerLooks
extends RefCounted

const FILE_NAMES := {
	"spoolGuard": "spool_guard",
	"thimbleMortar": "thimble_mortar",
	"prismSpire": "prism_spire",
}
const FALLBACK_FILE := "spool_guard"
const DIRECTORY := "res://render/looks/"


## The .tres file name (without extension) for a tower id.
static func file_name_for(type: String) -> String:
	return FILE_NAMES.get(type, FALLBACK_FILE)


## The look of a tower type; an unknown type gets the Spool Guard look.
static func for_type(type: String) -> TowerLook:
	return load(DIRECTORY + file_name_for(type) + ".tres") as TowerLook
