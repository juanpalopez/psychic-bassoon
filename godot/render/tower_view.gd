## One tower standing on its cell: a body that grows with each tier and a pip on
## top for each tier reached. It only draws; stats come from `content/`.
class_name TowerView
extends Node3D

const PIP_SIZE := 0.14
const PIP_GAP := 0.05

var tower_id := -1

var _height := 0.0

@onready var _body: MeshInstance3D = $Body
@onready var _pips: Node3D = $Pips


## Puts the tower on its cell, standing on a tile whose top is `surface_top`.
func setup(tower: Tower, look: TowerLook, surface_top: float) -> void:
	tower_id = tower.id
	var at := BoardSpace.cell_to_world(tower.col, tower.row)
	position = Vector3(at.x, surface_top, at.z)
	_height = look.base_height + look.height_per_level * float(tower.level)
	var box := BoxMesh.new()
	box.size = Vector3(look.foot, _height, look.foot)
	_body.mesh = box
	_body.position.y = _height / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = look.body_colour
	_body.material_override = material
	_build_pips(tower.level + 1, look)


## Height of the body, from the tile up.
func body_height() -> float:
	return _height


func body_colour() -> Color:
	return (_body.material_override as StandardMaterial3D).albedo_color


func pip_count() -> int:
	return _pips.get_child_count()


func _build_pips(count: int, look: TowerLook) -> void:
	for child in _pips.get_children():
		_pips.remove_child(child)
		child.queue_free()
	var material := StandardMaterial3D.new()
	material.albedo_color = look.pip_colour
	var step := PIP_SIZE + PIP_GAP
	for i in count:
		var pip := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(PIP_SIZE, PIP_SIZE, PIP_SIZE)
		pip.mesh = cube
		pip.material_override = material
		pip.position = Vector3((float(i) - float(count - 1) / 2.0) * step, _height + PIP_SIZE, 0.0)
		_pips.add_child(pip)
