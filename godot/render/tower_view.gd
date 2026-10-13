## One tower standing on its cell: a body that grows with each tier and a pip on
## top for each tier reached. It only draws; stats come from `content/`.
class_name TowerView
extends Node3D

const PIP_SIZE := 0.14
const PIP_GAP := 0.05
## A model grows by this share of its size at each tier (the box grows by the look's
## `height_per_level`).
const TIER_GROWTH := 0.12

var tower_id := -1

var _height := 0.0
var _has_model := false

@onready var _body: MeshInstance3D = $Body
@onready var _pips: Node3D = $Pips


## Puts the tower on its socket (at the middle of its block of `footprint` cells),
## standing on a tile whose top is `surface_top`.
func setup(tower: Tower, look: TowerLook, surface_top: float, footprint: int = 1) -> void:
	tower_id = tower.id
	var at := BoardSpace.footprint_centre(Vector2i(tower.col, tower.row), footprint)
	position = Vector3(at.x, surface_top, at.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = look.body_colour
	_body.material_override = material
	var packed := ModelLoader.scene(look.model_path)
	var model := packed.instantiate() as Node3D if packed != null else null
	var mesh := ModelLoader.first_mesh(model) if model != null else null
	if mesh != null:
		# the owner's model, a little bigger each tier, standing on the tile
		var scale := look.model_scale * (1.0 + TIER_GROWTH * float(tower.level))
		model.name = "Model"
		model.scale = Vector3(scale, scale, scale)
		add_child(model)
		_has_model = true
		_height = mesh.get_aabb().end.y * scale
		_body.mesh = null
	else:
		if model != null:
			model.free()
		_height = look.base_height + look.height_per_level * float(tower.level)
		var box := BoxMesh.new()
		box.size = Vector3(look.foot, _height, look.foot)
		_body.mesh = box
		_body.position.y = _height / 2.0
	_build_pips(tower.level + 1, look)


## How tall a tower of `level` is drawn with `look`, from the tile up: the model's
## height at its tier scale, or the box fallback's.
static func height_of(level: int, look: TowerLook) -> float:
	var mesh := ModelLoader.mesh(look.model_path)
	if mesh == null:
		return look.base_height + look.height_per_level * float(level)
	return mesh.get_aabb().end.y * look.model_scale * (1.0 + TIER_GROWTH * float(level))


## Whether the tower is drawn with its model (and not the box).
func has_model() -> bool:
	return _has_model


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
