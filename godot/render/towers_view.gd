## The towers in the game state, one `TowerView` scene each, standing on the
## socket's surface (`surface_height` takes a cell and returns the top of its
## tile). It only reads the towers; `fire` and `act` play a tower's clips when the
## game reports a shot or a guard coming out of its tent.
class_name TowersView
extends Node3D

const SCENE := preload("res://render/tower_view.tscn")
## Where a tower stands when no surface height is given.
const DEFAULT_TOP := 0.3

## tower id -> the state its view was drawn for (type, level, cell, footprint, top)
var _keys := {}
## tower id -> its view
var _views := {}
## tower id -> a clip asked for before the tower's view was made (a tent's first guard)
var _pending := {}


## Draws one scene per tower. A tower's view is remade only when it was added, upgraded or
## moved since the last call (a sold tower's view goes), so the others keep their clips and
## aim, and calling it every frame is cheap.
func sync(towers: Array[Tower], surface_height: Callable = Callable(), footprint: int = 1) -> void:
	var seen := {}
	for tower in towers:
		seen[tower.id] = true
		var top := DEFAULT_TOP
		if surface_height.is_valid():
			top = surface_height.call(Vector2i(tower.col, tower.row))
		var key := (
			"%s:%d:%d:%d:%d:%.3f" % [tower.type, tower.level, tower.col, tower.row, footprint, top]
		)
		if _keys.get(tower.id, "") == key:
			continue
		_drop(tower.id)
		var view := SCENE.instantiate() as TowerView
		add_child(view)
		view.setup(tower, TowerLooks.for_type(tower.type), top, footprint)
		_views[tower.id] = view
		_keys[tower.id] = key
		if _pending.has(tower.id):
			view.act(_pending[tower.id])
	_pending.clear()
	for id in _views.keys():
		if not seen.has(id):
			_drop(id)


## The tower `tower_id` shot at `target` (a world position).
func fire(tower_id: int, target: Vector3) -> void:
	var view := view_of(tower_id)
	if view != null:
		view.fire(target)


## Plays `clip` on the tower `tower_id`, when its model has it; a tower that has no view yet
## (built this tick) plays it when the next `sync` makes the view.
func act(tower_id: int, clip: String) -> void:
	var view := view_of(tower_id)
	if view != null:
		view.act(clip)
	else:
		_pending[tower_id] = clip


## The view drawing the tower `tower_id`, or null.
func view_of(tower_id: int) -> TowerView:
	return _views.get(tower_id)


func _drop(tower_id: int) -> void:
	var view: TowerView = _views.get(tower_id)
	if view != null:
		remove_child(view)
		view.queue_free()
	_views.erase(tower_id)
	_keys.erase(tower_id)
