## The towers in the game state, one `TowerView` scene each, standing on the
## socket's surface (`surface_height` takes a cell and returns the top of its
## tile). It only reads the towers.
class_name TowersView
extends Node3D

const SCENE := preload("res://render/tower_view.tscn")
## Where a tower stands when no surface height is given.
const DEFAULT_TOP := 0.3

var _key := ""


## Draws one scene per tower. It rebuilds only when a tower was added, sold or
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
		var top := DEFAULT_TOP
		if surface_height.is_valid():
			top = surface_height.call(Vector2i(tower.col, tower.row))
		var view := SCENE.instantiate() as TowerView
		add_child(view)
		view.setup(tower, TowerLooks.for_type(tower.type), top)
