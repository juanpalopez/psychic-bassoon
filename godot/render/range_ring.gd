## A flat translucent disc that shows how far a selected tower reaches. It is a
## unit disc scaled by the range, so the mesh is shared and never rebuilt.
class_name RangeRing
extends MeshInstance3D

## Lift above the tile so the disc does not flicker against it.
const LIFT := 0.04
const COLOUR := Color(0.2, 0.9, 0.9, 0.25)


func _ready() -> void:
	visible = false
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = material


## Shows the disc centred on `centre` (a point on the tile's top), `reach` cells wide.
func show_range(centre: Vector3, reach: float) -> void:
	position = Vector3(centre.x, centre.y + LIFT, centre.z)
	scale = Vector3(reach, 1.0, reach)
	visible = true


func hide_range() -> void:
	visible = false


func radius() -> float:
	return scale.x
