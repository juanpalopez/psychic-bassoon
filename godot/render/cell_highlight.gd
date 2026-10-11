## A flat, see-through square laid over the selected cell.
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
	var at := BoardSpace.cell_to_world(cell.x, cell.y)
	position = Vector3(at.x, height + LIFT, at.z)
	_material.albedo_color = colour
	visible = true


func hide_cell() -> void:
	visible = false
