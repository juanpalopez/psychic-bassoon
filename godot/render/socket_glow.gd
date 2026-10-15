## A pulsing ring over every socket block it is told about (the intro asks the player to tap
## one). It only draws; the scene says which blocks and how tall each tile is.
class_name SocketGlow
extends Node3D

const LIFT := 0.06
const INNER := 0.78
const OUTER := 0.95
const COLOUR := Color(1.0, 0.85, 0.4)
const PULSE_SPEED := 4.0
const MIN_ALPHA := 0.35

var _rings: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _clock := 0.0


func _init() -> void:
	visible = false
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOUR


## Puts a ring over each block of `footprint` cells (given by its top-left cell), resting on a
## tile `surface_height` tall (a Callable from cell to height). Replaces the rings shown before.
func show_blocks(anchors: Array[Vector2i], footprint: int, surface_height: Callable) -> void:
	_clear()
	for anchor in anchors:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = INNER * float(footprint) / 2.0
		torus.outer_radius = OUTER * float(footprint) / 2.0
		ring.mesh = torus
		ring.material_override = _material
		var at := BoardSpace.footprint_centre(anchor, footprint)
		at.y = float(surface_height.call(anchor)) + LIFT
		ring.position = at
		add_child(ring)
		_rings.append(ring)
	visible = not _rings.is_empty()


func hide_all() -> void:
	_clear()
	visible = false


func ring_count() -> int:
	return _rings.size()


func ring_position(index: int) -> Vector3:
	return _rings[index].position


## The brightness now, from MIN_ALPHA to 1.
func pulse() -> float:
	return _material.albedo_color.a


func advance(delta: float) -> void:
	_clock += delta
	var wave := 0.5 + 0.5 * sin(_clock * PULSE_SPEED)
	_material.albedo_color = Color(COLOUR, MIN_ALPHA + (1.0 - MIN_ALPHA) * wave)


func _process(delta: float) -> void:
	if visible:
		advance(delta)


func _clear() -> void:
	for ring in _rings:
		remove_child(ring)
		ring.queue_free()
	_rings.clear()
