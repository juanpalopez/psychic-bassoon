## A flat, see-through square laid over the selected cell or socket block.
class_name CellHighlight
extends Node3D

const SIZE := Vector3(1.0, 0.04, 1.0)
const LIFT := 0.03

var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _init() -> void:
	visible = false
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SIZE
	_mesh.mesh = box
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _material
	add_child(_mesh)


## Shows the square on `cell`, resting on a tile `height` tall.
func show_cell(cell: Vector2i, height: float, colour: Color) -> void:
	show_block(cell, 1, height, colour)


## Shows the square over a block of `footprint` cells whose top-left cell is
## `anchor`.
func show_block(anchor: Vector2i, footprint: int, height: float, colour: Color) -> void:
	var at := BoardSpace.footprint_centre(anchor, footprint)
	position = Vector3(at.x, height + LIFT, at.z)
	scale = Vector3(float(footprint), 1.0, float(footprint))
	_material.albedo_color = colour
	visible = true


func hide_cell() -> void:
	visible = false
