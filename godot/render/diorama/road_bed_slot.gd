## The diorama's `RoadBeds` slot (#325): `RoadBedBuilder`'s road beds and bridges, built from the
## field's map and routes on the field's terrain tops. Two meshes, two draw calls, each wearing
## its own look (the bed its flagstones, the bridges the painted paper).
@tool
class_name RoadBedSlot
extends DioramaBuilder


func build(field: TerrainField) -> void:
	clear()
	var made := RoadBedBuilder.build(field.map, field.routes, Callable(field, "top_at"))
	for child in made.get_children():
		var part := child as MeshInstance3D
		var casts := part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var look: Material = null
		if part.mesh.get_surface_count() > 0:
			look = part.mesh.surface_get_material(0)
		add_mesh(part.name, part.mesh, look, casts)
	made.free()
