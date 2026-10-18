## The diorama's `Scatter` slot (#326): `SceneryScatter`'s forests, rocks, dirt and grass from
## the field. One MultiMesh per prop kind per chunk.
@tool
class_name ScenerySlot
extends DioramaBuilder

## Every prop of the last build, kept because the headless renderer cannot read a MultiMesh
## back (`docs/lessons/2026-10-18-headless-multimesh-transforms.md`).
var placements: Array[SceneryScatter.Placement] = []


func build(field: TerrainField) -> void:
	clear()
	placements = SceneryScatter.placements(field)
	var made := SceneryScatter.build_from(placements, field)
	for child in made.get_children():
		made.remove_child(child)
		add_child(child)
		var multimesh := (child as MultiMeshInstance3D).multimesh
		count(multimesh.mesh, multimesh.instance_count)
	made.free()
