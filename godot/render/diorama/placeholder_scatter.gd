## A placeholder scatter until #326 brings the seeded forests, rocks, dirt and grass: the paper
## trees, shrubs, grass and flowers the board had, now standing on the terraces of the map's
## open cells (never on the road, a socket, the Heartstone or the river). One MultiMesh per
## model. Which cell gets what, where in it and how it is turned come from a hash of the cell
## and the seed.
@tool
class_name PlaceholderScatter
extends DioramaBuilder

const TERRAIN := "res://assets/models/terrain/"
## Model, cells from the road it must keep (Chebyshev), the share of eligible cells that get
## one, and the cells it keeps off a socket block and the Heartstone (a tree leans a metre or
## more past its cell, so a cell next door would stand over a built tower).
const DECOR := {
	"Trees": ["decor_tree_pine", 2, 0.4, 2],
	"RoundTrees": ["decor_tree_round", 2, 0.25, 2],
	"Shrubs": ["decor_shrub", 1, 0.35, 2],
	"Grass": ["decor_grass", 1, 0.45, 1],
	"Flowers": ["decor_flowers", 1, 0.14, 1],
}
## The decor tall enough to cast a shadow worth its draw call.
const CASTS_SHADOW: Array[String] = ["Trees", "RoundTrees", "Shrubs"]

## The cells that hold decor, and where each piece stands, by decor name (the keys of DECOR);
## kept because the headless renderer cannot read a MultiMesh back.
var decor_cells := {}
var decor_spots := {}


func build(field: TerrainField) -> void:
	clear()
	decor_cells.clear()
	decor_spots.clear()
	var map := field.map
	var road := {}
	for route in map.routes:
		for cell in route:
			road[cell] = true
	var blocked := {}
	for anchor in map.sockets:
		for dy in map.footprint:
			for dx in map.footprint:
				blocked[anchor + Vector2i(dx, dy)] = true
	var heart := map.heartstone
	for dy in heart.size.y:
		for dx in heart.size.x:
			blocked[heart.position + Vector2i(dx, dy)] = true
	var placed := {}
	for key in DECOR:
		placed[key] = []
		decor_cells[key] = [] as Array[Vector2i]
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			if road.has(cell) or blocked.has(cell) or field.is_gorge(cell):
				continue
			var from_road := _distance_to(cell, road)
			var from_blocked := _distance_to(cell, blocked)
			var tree := CellHash.of(col, row, field.seed, 10)
			if (
				from_road >= 2
				and from_blocked >= DECOR["Trees"][3]
				and tree < DECOR["Trees"][2] + DECOR["RoundTrees"][2]
			):
				var key := "Trees" if tree < DECOR["Trees"][2] else "RoundTrees"
				_place(field, placed, key, cell, 0.9, 1.25)
				continue
			if (
				from_road >= DECOR["Shrubs"][1]
				and from_blocked >= DECOR["Shrubs"][3]
				and CellHash.of(col, row, field.seed, 11) < DECOR["Shrubs"][2]
			):
				_place(field, placed, "Shrubs", cell, 0.8, 1.2)
			for key in ["Grass", "Flowers"]:
				var salt: int = 12 + DECOR.keys().find(key)
				if (
					from_road >= DECOR[key][1]
					and from_blocked >= DECOR[key][3]
					and CellHash.of(col, row, field.seed, salt) < DECOR[key][2]
				):
					_place(field, placed, key, cell, 0.8, 1.2)
	for key in DECOR:
		decor_spots[key] = placed[key]
		_scatter(key, DECOR[key][0], placed[key])


func _place(
	field: TerrainField, placed: Dictionary, key: String, cell: Vector2i, small: float, big: float
) -> void:
	var salt := 30 + DECOR.keys().find(key)
	var at := field.cell_centre(cell)
	at.x += (CellHash.of(cell.x, cell.y, field.seed, salt) - 0.5) * 0.5
	at.z += (CellHash.of(cell.x, cell.y, field.seed, salt + 50) - 0.5) * 0.5
	at.y = field.top_at(cell)
	var turn := CellHash.of(cell.x, cell.y, field.seed, salt + 100) * TAU
	var scale := lerpf(small, big, CellHash.of(cell.x, cell.y, field.seed, salt + 150))
	placed[key].append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale), at))
	decor_cells[key].append(cell)


func _scatter(node_name: String, model: String, spots: Array) -> void:
	var mesh := PaperLook.dress(ModelLoader.mesh(TERRAIN + model + ".glb"))
	if mesh == null or spots.is_empty():
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, spots[i])
	instance.multimesh = multimesh
	if not node_name in CASTS_SHADOW:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	count(mesh, spots.size())


## How many cells (Chebyshev) from `cell` to the nearest cell in `cells`, at most 9.
static func _distance_to(cell: Vector2i, cells: Dictionary) -> int:
	var best := 9
	for other in cells:
		var d: Vector2i = (other - cell).abs()
		best = mini(best, maxi(d.x, d.y))
	return best
