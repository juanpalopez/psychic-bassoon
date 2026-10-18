## One part of the diorama (the terraces, the water, the road beds, the scatter): a node that
## builds its meshes from the `TerrainField` and owns every child it adds.
##
## To plug a builder in (#325 the road beds and bridges, #326 the scatter), extend this class,
## override `build`, and give it to `Diorama.use_builder` under its slot name. A builder must
## not depend on another builder's output: each reads the field (and the map in it) only.
@tool
class_name DioramaBuilder
extends Node3D

## What the last build drew: triangles and surfaces (a surface is a draw call per pass).
var triangles: int = 0
var surfaces: int = 0


## Builds this part for the field, replacing whatever the last build made.
func build(_field: TerrainField) -> void:
	clear()


## Frees everything this builder made.
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	triangles = 0
	surfaces = 0


## Adds a mesh as a child and counts it.
func add_mesh(node_name: String, mesh: Mesh, material: Material, shadows: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	count(mesh, 1)
	return instance


## Counts `instances` copies of a mesh in `triangles` and `surfaces`.
func count(mesh: Mesh, instances: int) -> void:
	if mesh == null or instances <= 0:
		return
	surfaces += mesh.get_surface_count()
	if not mesh is ArrayMesh:
		triangles += int(mesh.get_faces().size() / 3.0) * instances
		return
	var arrays := mesh as ArrayMesh
	for i in arrays.get_surface_count():
		var corners := arrays.surface_get_array_index_len(i)
		if corners <= 0:
			corners = arrays.surface_get_array_len(i)
		triangles += int(corners / 3.0) * instances


## A surface from flat arrays of triangle corners (no index): positions, normals and colours.
static func triangles_mesh(
	vertices: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
