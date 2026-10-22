## The diorama's scenery (#326): forest patches of cone pines and round broadleaf trees, shrubs,
## faceted boulders, dirt patches and grass tufts, scattered by the map's regions on the board
## and, past it, by a render-only rule (forest and rocks from smooth noise on the map's seed),
## out to a ring `SCATTER_RING` cells beyond each edge, thicker and taller further out. It reads
## the diorama's `TerrainField`: the map, the routes, and the ground props stand on.
##
## No prop's footprint ever covers a socket block, the Heartstone's block, the road bed (its
## drawn centrelines, carried on past the board), a bridge's deck or the river (the field's,
## carried on past the board), and each kind keeps its own extra distance
## (`DioramaLooks.KEEP_OFF_*`), so trees stand back from the road and the towers. A prop stands
## only where its whole footprint is on one terrace: never in the gorge, never across a cliff.
##
## `build` returns one `MultiMeshInstance3D` per prop kind per chunk: the board and its margin in
## two halves (west and east of the board's middle), and the ring round them in two halves (which
## holds only the forest and the boulders, in lighter meshes), so a view of one end of the board
## culls the other end's scenery: 18 surfaces, 10 of them in the shadow map. Every choice comes
## from `CellHash` on the cell and the map's seed, so the same map always gets the same scenery,
## and nothing reads or moves the game's random streams.
class_name SceneryScatter
extends RefCounted

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
## The chunks: the board and its margin in two halves, and the ring past it in two halves.
const MIDDLE: Array[String] = ["CentreWest", "CentreEast"]
const RING: Array[String] = ["RingWest", "RingEast"]
## The kinds that grow in the ring past the margin.
const FAR_KINDS: Array[String] = ["pine", "broadleaf", "boulder"]
## The node name of each kind's MultiMesh.
const NAMES := {
	"pine": "Pines",
	"broadleaf": "Broadleaves",
	"shrub": "Shrubs",
	"boulder": "Boulders",
	"dirt": "DirtPatches",
	"grass": "GrassTufts",
}
const TREES: Array[String] = ["pine", "broadleaf"]
## Salts for `CellHash`, so the draws for one cell differ.
const SALT_COUNT := 101
const SALT_X := 102
const SALT_Y := 103
const SALT_SIZE := 104
const SALT_TURN := 105
const SALT_TINT := 106
const SALT_WARM := 107
const SALT_STRETCH := 108
const SALT_FOREST := 109
const SALT_ROCKS := 110
## Where in its cell a prop may stand (a share of the cell from its edge).
const CELL_INSET := 0.12


## One prop: its kind, where it stands (sim cells, x across and y down), its footprint radius
## there (cells), its size, turn and height stretch, its tint and its chunk.
class Placement:
	extends RefCounted
	var kind: String
	var at: Vector2
	var radius: float
	var size: float
	var turn: float
	var stretch: float
	var tint: Color
	var chunk: String


## The scenery for a diorama's field. The node holds one MultiMeshInstance3D per kind per chunk,
## named like `Pines_CentreWest`.
static func build(field: TerrainField) -> Node3D:
	return build_from(placements(field), field)


## The nodes for `found` (from `placements`) on the field's ground.
static func build_from(found: Array[Placement], field: TerrainField) -> Node3D:
	var root := Node3D.new()
	root.name = "Scenery"
	var groups := {}
	for placement in found:
		var key := "%s_%s" % [NAMES[placement.kind], placement.chunk]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(placement)
	var keys := groups.keys()
	keys.sort()
	var ground := Callable(field, "top_at")
	for key: String in keys:
		var group: Array = groups[key]
		var first: Placement = group[0]
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.multimesh = _multimesh(group, first.kind, not MIDDLE.has(first.chunk), ground)
		# only trees and boulders cast: ground cover is flat, a shrub's shadow is lost under it,
		# and a boulder far out is too small to show one
		var casts := TREES.has(first.kind) or (first.kind == "boulder" and MIDDLE.has(first.chunk))
		if not casts:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return root


## Every prop of the scenery, in a fixed order (by cell, then kind).
static func placements(field: TerrainField) -> Array[Placement]:
	var map := field.map
	var keep_off := Obstacles.new(field)
	var found: Array[Placement] = []
	var ring := LOOKS.SCATTER_RING
	for row in range(-ring, map.rows + ring):
		for col in range(-ring, map.cols + ring):
			var cell := Vector2i(col, row)
			# nothing stands in the gorge, or on a road cell, a socket or the Heartstone (a
			# corner cell's outer corner is off the bed but still the road's)
			if field.is_gorge(cell) or field.guard_at(cell) != TerrainField.GUARD_NONE:
				continue
			var out := _distance_out(map, cell)
			var region := _region(map, cell, out)
			var chunk := chunk_of(map, Vector2(col, row) + Vector2(0.5, 0.5))
			var reach := clampf(float(out) / LOOKS.OUTSIDE_FULL, 0.0, 1.0)
			for k in SceneryProps.KINDS.size():
				var kind := SceneryProps.KINDS[k]
				if not MIDDLE.has(chunk) and not FAR_KINDS.has(kind):
					continue
				var density: float = LOOKS.DENSITY[kind][region]
				if out > 0 and TREES.has(kind):
					var grow := lerpf(1.0, LOOKS.OUTSIDE_TREE_SCALE, reach)
					density *= lerpf(1.0, LOOKS.OUTSIDE_COVER, reach) / (grow * grow)
				var count := int(floor(density))
				if CellHash.of(col, row, map.seed, SALT_COUNT + k * 16) < density - float(count):
					count += 1
				for n in count:
					var placement := _placement(map, cell, kind, k * 8 + n, reach)
					placement.chunk = chunk
					if on_one_terrace(field, placement) and keep_off.clear(placement):
						found.append(placement)
	return found


## True when every cell under a prop's footprint is on the terrace of the cell it stands in (so
## none is in the gorge and the footprint crosses no cliff).
static func on_one_terrace(field: TerrainField, placement: Placement) -> bool:
	var at := placement.at
	var r := placement.radius
	var level := field.level_at(Vector2i(floori(at.x), floori(at.y)))
	if level == TerrainField.GORGE:
		return false
	for row in range(floori(at.y - r), floori(at.y + r) + 1):
		for col in range(floori(at.x - r), floori(at.x + r) + 1):
			var cell := Vector2i(col, row)
			var rect := Rect2(Vector2(cell), Vector2.ONE)
			if at.distance_to(at.clamp(rect.position, rect.end)) >= r:
				continue
			if field.level_at(cell) != level:
				return false
	return true


## The chunk a point (sim cells) falls in: the board and `SCATTER_CENTRE_MARGIN` cells round it
## (`CentreWest` or `CentreEast` of the board's middle column), or the ring past that margin, in
## the same two halves (`RingWest`, `RingEast`).
static func chunk_of(map: GameMap, at: Vector2) -> String:
	var margin := float(LOOKS.SCATTER_CENTRE_MARGIN)
	var west := at.x < float(map.cols) / 2.0
	var inside := Rect2(
		Vector2(-margin, -margin), Vector2(map.cols, map.rows) + Vector2.ONE * 2.0 * margin
	)
	if inside.has_point(at):
		return MIDDLE[0] if west else MIDDLE[1]
	return RING[0] if west else RING[1]


## How many cells a cell lies outside the board (0 on it), counted along the nearer axis's gap.
static func _distance_out(map: GameMap, cell: Vector2i) -> int:
	var dx := maxi(maxi(-cell.x, cell.x - (map.cols - 1)), 0)
	var dy := maxi(maxi(-cell.y, cell.y - (map.rows - 1)), 0)
	return maxi(dx, dy)


## The region of a cell: the map's on the board; past it, a forest or rocks cell at the edge
## carries on for a few cells, then smooth noise picks forest, rocks or meadow.
static func _region(map: GameMap, cell: Vector2i, out: int) -> int:
	if out == 0:
		return map.region_at(cell)
	if out <= LOOKS.OUTSIDE_CARRY:
		var edge := Vector2i(clampi(cell.x, 0, map.cols - 1), clampi(cell.y, 0, map.rows - 1))
		var there := map.region_at(edge)
		if there == GameMap.Region.FOREST or there == GameMap.Region.ROCKS:
			return there
	var reach := clampf(float(out) / LOOKS.OUTSIDE_FULL, 0.0, 1.0)
	var forest_above := LOOKS.OUTSIDE_FOREST_ABOVE - LOOKS.OUTSIDE_FOREST_GROWTH * reach
	if _noise(cell, map.seed, SALT_FOREST) > forest_above:
		return GameMap.Region.FOREST
	if _noise(cell, map.seed, SALT_ROCKS) < LOOKS.OUTSIDE_ROCKS_BELOW:
		return GameMap.Region.ROCKS
	return GameMap.Region.MEADOW


## Smooth value noise in [0, 1): a hashed value every `OUTSIDE_NOISE_CELL` cells, blended.
static func _noise(cell: Vector2i, map_seed: int, salt: int) -> float:
	var at := Vector2(cell) / float(LOOKS.OUTSIDE_NOISE_CELL)
	var knot := Vector2i(floori(at.x), floori(at.y))
	var t := at - Vector2(knot)
	t = t * t * (Vector2(3.0, 3.0) - 2.0 * t)
	var a := CellHash.of(knot.x, knot.y, map_seed, salt)
	var b := CellHash.of(knot.x + 1, knot.y, map_seed, salt)
	var c := CellHash.of(knot.x, knot.y + 1, map_seed, salt)
	var d := CellHash.of(knot.x + 1, knot.y + 1, map_seed, salt)
	return lerpf(lerpf(a, b, t.x), lerpf(c, d, t.x), t.y)


## The `n`-th draw of a kind in a cell: where in the cell, how big, turned and tinted how.
static func _placement(
	map: GameMap, cell: Vector2i, kind: String, n: int, reach: float
) -> Placement:
	var hash := func(salt: int) -> float:
		return CellHash.of(cell.x, cell.y, map.seed, salt * 64 + n)
	var placement := Placement.new()
	placement.kind = kind
	var span := 1.0 - 2.0 * CELL_INSET
	placement.at = (
		Vector2(cell)
		+ Vector2(CELL_INSET + span * hash.call(SALT_X), CELL_INSET + span * hash.call(SALT_Y))
	)
	var size := lerpf(LOOKS.SCALE_MIN, LOOKS.SCALE_MAX, hash.call(SALT_SIZE))
	if TREES.has(kind):
		size *= lerpf(1.0, LOOKS.OUTSIDE_TREE_SCALE, reach)
	placement.size = size
	placement.radius = SceneryProps.reach(kind) * size
	placement.turn = TAU * hash.call(SALT_TURN)
	placement.stretch = 1.0
	if TREES.has(kind):
		placement.stretch = 1.0 + (hash.call(SALT_STRETCH) - 0.5) * 2.0 * LOOKS.TREE_STRETCH
	var light: float = 1.0 + (hash.call(SALT_TINT) - 0.5) * 2.0 * LOOKS.TINT
	var warm: float = (hash.call(SALT_WARM) - 0.5) * 2.0 * LOOKS.TINT
	placement.tint = Color(light + warm, light + warm * 0.4, light - warm)
	return placement


## Where a prop stands in the world: on the terrain top of its cell, turned and sized.
static func instance_transform(placement: Placement, height_fn: Callable) -> Transform3D:
	var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
	var ground := float(height_fn.call(cell))
	var at := BoardSpace.point_to_world(placement.at.x, placement.at.y)
	var scale := Vector3(placement.size, placement.size * placement.stretch, placement.size)
	var basis := Basis(Vector3.UP, placement.turn).scaled(scale)
	return Transform3D(basis, Vector3(at.x, ground, at.z))


static func _multimesh(group: Array, kind: String, light: bool, height_fn: Callable) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = SceneryProps.mesh(kind, light)
	multimesh.instance_count = group.size()
	for i in group.size():
		var placement: Placement = group[i]
		multimesh.set_instance_transform(i, instance_transform(placement, height_fn))
		multimesh.set_instance_color(i, placement.tint)
	return multimesh


## What the scenery keeps off, bucketed by cell so a prop checks only what is near it: the
## road's drawn centrelines (as segments with the bed's half width), and rectangles for the
## socket blocks, the Heartstone's block, the bridges' decks and the river's cells (the field's,
## carried on past the board).
class Obstacles:
	extends RefCounted
	## Cells round an obstacle that a prop near it may stand in: more than the biggest tree's
	## footprint (a broadleaf at full size outside, about 1.15 cells) plus the largest keep-off
	## (0.5) and the bed's half width (0.475; 1.25 on the wide band).
	const REACH := 4
	var _from := PackedVector2Array()
	var _to := PackedVector2Array()
	## Each rectangle and how far a prop of each kind keeps off it ("socket", "bridge", "river").
	var _rects: Array[Rect2] = []
	var _rect_kinds: Array[String] = []
	var _buckets := {}
	## Half the road bed's width: the map's (`GameMap.road_width`).
	var _road_half := LOOKS.ROAD_WIDTH / 2.0

	## Everything `field` keeps clear, or nothing for a null field (add to it by hand).
	func _init(field: TerrainField) -> void:
		if field == null:
			return
		var map := field.map
		_road_half = map.road_width / 2.0
		for line in RoadBedBuilder.centrelines(field.routes):
			for k in line.size() - 1:
				add_segment(line[k], line[k + 1])
		for anchor in map.sockets:
			add_rect(Rect2(Vector2(anchor), Vector2(map.footprint, map.footprint)), "socket")
		add_rect(Rect2(map.heartstone), "socket")
		for bridge in map.bridges:
			add_rect(RoadBedBuilder.deck_rect(bridge), "bridge")
		for cell in field.river:
			add_rect(Rect2(Vector2(cell), Vector2.ONE), "river")

	## True when `placement`'s footprint, with its kind's keep-off, touches nothing.
	func clear(placement: Placement) -> bool:
		var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
		var kind := placement.kind
		var half := _road_half + LOOKS.ROAD_WOBBLE
		for index: int in _buckets.get(cell, []):
			if index >= 0:
				var closest := Geometry2D.get_closest_point_to_segment(
					placement.at, _from[index], _to[index]
				)
				var gap: float = half + placement.radius + LOOKS.KEEP_OFF_ROAD[kind]
				if placement.at.distance_to(closest) < gap:
					return false
				continue
			var rect := _rects[-index - 1]
			var keep := LOOKS.KEEP_OFF_RIVER
			match _rect_kinds[-index - 1]:
				"socket":
					keep = LOOKS.KEEP_OFF_SOCKET[kind]
				"bridge":
					keep = LOOKS.KEEP_OFF_BRIDGE
			var nearest := placement.at.clamp(rect.position, rect.end)
			if placement.at.distance_to(nearest) < placement.radius + keep:
				return false
		return true

	## A stretch of the road bed's middle line.
	func add_segment(a: Vector2, b: Vector2) -> void:
		_from.append(a)
		_to.append(b)
		var low := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		_bucket(Rect2(low, high - low), _from.size() - 1)

	## A rectangle to keep off: `kind` is "socket", "bridge" or "river".
	func add_rect(rect: Rect2, kind: String) -> void:
		_rects.append(rect)
		_rect_kinds.append(kind)
		_bucket(rect, -_rects.size())

	func _bucket(area: Rect2, index: int) -> void:
		var low := (
			Vector2i(floori(area.position.x), floori(area.position.y)) - Vector2i(REACH, REACH)
		)
		var high := Vector2i(floori(area.end.x), floori(area.end.y)) + Vector2i(REACH, REACH)
		for row in range(low.y, high.y + 1):
			for col in range(low.x, high.x + 1):
				var key := Vector2i(col, row)
				if not _buckets.has(key):
					_buckets[key] = []
				_buckets[key].append(index)
