## The diorama's `RoadBeds` slot (#325): `RoadBedBuilder`'s road beds and bridges, built from the
## field's map and routes on the field's terrain tops. Two meshes, two draw calls.
@tool
class_name RoadBedSlot
extends DioramaBuilder


func build(field: TerrainField) -> void:
	clear()
	var made := RoadBedBuilder.build(field.map, field.routes, Callable(field, "top_at"))
	for child in made.get_children():
		made.remove_child(child)
		add_child(child)
		count((child as MeshInstance3D).mesh, 1)
	made.free()
