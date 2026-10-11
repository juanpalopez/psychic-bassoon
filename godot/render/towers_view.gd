## Greybox markers for the towers in the game state: a box on each tower's
## cell, taller with each level, coloured by type, standing on the socket's
## surface (`surface_height` takes a cell and returns the top of its tile). It
## only reads the towers; the real tower scenes arrive in step A4.
class_name TowersView
extends Node3D

const FOOT := 0.6
const BASE_HEIGHT := 0.9
const HEIGHT_PER_LEVEL := 0.35
## Where a tower stands when no surface height is given.
const DEFAULT_TOP := 0.3
const COLOURS := {
	"ballista": Color("00bcd4"),
	"catapult": Color("e67e22"),
	"frostSpire": Color("8e44ad"),
	"stormSpire": Color("f1c40f"),
}
const FALLBACK_COLOUR := Color("cccccc")

var _key := ""


## Draws one marker per tower. It rebuilds only when a tower was added, sold or
## upgraded since the last call, so calling it every frame is cheap.
func sync(towers: Array[Tower], surface_height: Callable = Callable()) -> void:
	var key := ""
	for tower in towers:
		key += "%d:%s:%d:%d:%d;" % [tower.id, tower.type, tower.level, tower.col, tower.row]
	if key == _key:
		return
	_key = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for tower in towers:
		add_child(_marker(tower, surface_height))


func _marker(tower: Tower, surface_height: Callable) -> MeshInstance3D:
	var height := BASE_HEIGHT + HEIGHT_PER_LEVEL * float(tower.level)
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(FOOT, height, FOOT)
	marker.mesh = box
	var at := BoardSpace.cell_to_world(tower.col, tower.row)
	var top := DEFAULT_TOP
	if surface_height.is_valid():
		top = surface_height.call(Vector2i(tower.col, tower.row))
	marker.position = Vector3(at.x, top + height / 2.0, at.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOURS.get(tower.type, FALLBACK_COLOUR)
	marker.material_override = material
	return marker
