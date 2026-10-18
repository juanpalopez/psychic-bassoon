## One tower standing on its cell: its papercraft model, a little bigger each tier, and a pip
## on top for each tier reached. The model's parts play stop-motion clips (`StopMotion`): an
## idle loop, and its action when the game says so (a shot for the shooting towers, the door
## for the Guard Tent). A tower whose look `aims` turns its `*_Aim` pivot (the empty above
## its Head, which no clip moves) to what it shot. It only draws; stats come from `content/`.
class_name TowerView
extends Node3D

const PIP_SIZE := 0.14
const PIP_GAP := 0.05
## A model grows by this share of its size at each tier (the box grows by the look's
## `height_per_level`).
const TIER_GROWTH := 0.12
## The clips that loop; every other clip plays once and the tower goes back to idling.
const LOOPS: Array[String] = ["idle"]
## Seconds a tower keeps its aim after a shot before it idles (and looks round) again.
const AIM_HOLD := 1.5

var tower_id := -1

var _height := 0.0
var _has_model := false
var _aims := false
var _player: AnimationPlayer
var _aim: Node3D
var _aim_left := 0.0

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
	var old := get_node_or_null("Model")
	if old != null:
		remove_child(old)
		old.queue_free()
	_player = null
	_aim = null
	_has_model = false
	var packed := ModelLoader.scene(look.model_path)
	var model := packed.instantiate() as Node3D if packed != null else null
	if model != null and ModelLoader.first_mesh(model) != null:
		# the owner's model, a little bigger each tier, standing on the tile
		var scale := look.model_scale * (1.0 + TIER_GROWTH * float(tower.level))
		model.name = "Model"
		model.scale = Vector3(scale, scale, scale)
		StopMotion.dress(model)
		# only the base casts a shadow: the moving parts would double their draw calls
		StopMotion.cast_shadows(model, "_Base")
		add_child(model)
		_has_model = true
		_height = ModelLoader.bounds(look.model_path).end.y * scale
		_body.mesh = null
		_aims = look.aims
		_aim = StopMotion.part(model, "_Aim")
		_player = StopMotion.player_of(model)
		if _player != null:
			StopMotion.prepare(_player, LOOPS)
			_play("idle")
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
	var box := ModelLoader.bounds(look.model_path)
	if box.size == Vector3.ZERO:
		return look.base_height + look.height_per_level * float(level)
	return box.end.y * look.model_scale * (1.0 + TIER_GROWTH * float(level))


## The tower shot at `target` (a world position): it turns to it, if it aims, and plays
## its shot.
func fire(target: Vector3) -> void:
	if _aims and _aim != null:
		var local := to_local(target)
		_aim.rotation.y = atan2(local.x, local.z)
	_aim_left = AIM_HOLD
	act("fire")


## Plays the model's `clip` from its start, when the model has it.
func act(clip: String) -> void:
	if _player != null and _player.has_animation(clip):
		_player.stop()
		_play(clip)


## The clip playing now ("" when there is none).
func clip() -> String:
	return _player.current_animation if _player != null else ""


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


## Moves the clips on by `delta` seconds: a finished action goes back to idling once the
## tower has held its aim.
func advance(delta: float) -> void:
	if _player == null:
		return
	_aim_left = maxf(_aim_left - delta, 0.0)
	if not _player.is_playing() and _aim_left <= 0.0:
		_play("idle")


func _process(delta: float) -> void:
	advance(delta)


func _play(clip_name: String) -> void:
	if _player.has_animation(clip_name):
		_player.play(clip_name)


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
