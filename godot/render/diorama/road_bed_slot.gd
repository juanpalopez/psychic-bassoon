## The diorama's `RoadBeds` slot (#325): `RoadBedBuilder`'s road beds and bridges, built from the
## field's map and routes on the field's terrain tops. Two meshes, two draw calls.
@tool
class_name RoadBedSlot
extends DioramaBuilder


func build(field: TerrainField) -> void:
	clear()
	# the bed and the bridges fade into the haze past the map, as the terrain does
	var half := Vector2(float(field.map.cols), float(field.map.rows)) / 2.0
	RoadBedBuilder.bed_material().set_shader_parameter("map_half", half)
	PaperLook.material("diorama_vc").set_shader_parameter("map_half", half)
	var made := RoadBedBuilder.build(field.map, field.routes, Callable(field, "top_at"))
	for child in made.get_children():
		made.remove_child(child)
		add_child(child)
		count((child as MeshInstance3D).mesh, 1)
	made.free()
