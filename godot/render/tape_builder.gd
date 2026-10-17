## Masking tape along a map's roads, as one mesh. Each stretch of road cells that no earlier
## route has taped gets strips, one per straight run, from the taped cell before it (where it
## leaves a road) to the taped cell after it (where it joins one), so a feeder and a detour
## both get tape. Strips run a little past their ends so they overlap at the corners, and
## have torn ends and a slight wobble taken from CellHash. Strips that overlap lie at
## different heights so they never z-fight. UV.x runs along a strip in metres, UV.y across
## it from 0 to 1. Every triangle faces up with the same winding.
class_name TapeBuilder
extends RefCounted

const WIDTH := 0.84
## The height of the first strip; later strips lie a step higher where they overlap, all
## under Board.ROAD_HEIGHT. A step is a few depth-buffer steps at the camera's distance.
const HEIGHT := 0.004
const STEP := 0.0018
const LAYERS := 4
## How far a strip runs past its last cell, and back from a road's first cell into the ink.
const OVERRUN := 0.46
const LEAD_IN := 0.8


## The tape for `routes` (lists of cells) on the board of `map_seed`.
static func build(routes: Array, map_seed: int) -> ArrayMesh:
	var taped := {}
	## The layers of the strips lying over each cell (or reaching into it).
	var layers := {}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strip := 0
	for route in routes:
		var i := 0
		while i < route.size():
			if taped.has(route[i]):
				i += 1
				continue
			var first := i
			while i < route.size() and not taped.has(route[i]):
				i += 1
			var cells: Array[Vector2i] = []
			for k in range(maxi(first - 1, 0), mini(i, route.size() - 1) + 1):
				cells.append(route[k])
			for run in runs(cells):
				var lead := LEAD_IN if first == 0 and run[0] == 0 else OVERRUN
				var from: Vector2i = cells[run[0]]
				var to: Vector2i = cells[run[1]]
				var under := _reach(from, to)
				var layer := _free_layer(layers, under, strip)
				for cell in under:
					var here: Array = layers.get(cell, [])
					here.append(layer)
					layers[cell] = here
				_strip(surface, from, to, lead, strip, layer, map_seed)
				strip += 1
		for cell in route:
			taped[cell] = true
	surface.generate_tangents()
	return surface.commit()


## The cells a strip from `from` to `to` covers, with the cell past each end its overrun
## reaches into.
static func _reach(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var cells: Array[Vector2i] = [from - step]
	var cell := from
	while cell != to:
		cells.append(cell)
		cell += step
	cells.append(to)
	cells.append(to + step)
	return cells


## A layer no strip over `cells` uses, trying `strip`'s own layer first so neighbours vary.
static func _free_layer(layers: Dictionary, cells: Array[Vector2i], strip: int) -> int:
	var used := {}
	for cell in cells:
		for layer in layers.get(cell, []):
			used[layer] = true
	for k in LAYERS:
		var layer := (strip + k) % LAYERS
		if not used.has(layer):
			return layer
	return strip % LAYERS


## The straight runs of a list of cells, as [first index, last index] pairs; a corner cell
## ends one run and starts the next.
static func runs(cells: Array[Vector2i]) -> Array:
	var found := []
	var first := 0
	for i in range(1, cells.size() - 1):
		if cells[i + 1] - cells[i] != cells[i] - cells[i - 1]:
			found.append([first, i])
			first = i
	found.append([first, cells.size() - 1])
	return found


static func _strip(
	surface: SurfaceTool,
	from: Vector2i,
	to: Vector2i,
	lead: float,
	index: int,
	layer: int,
	map_seed: int
) -> void:
	var start := BoardSpace.cell_to_world(from.x, from.y)
	var end := BoardSpace.cell_to_world(to.x, to.y)
	var along := (end - start).normalized() if from != to else Vector3.RIGHT
	start -= along * lead
	end += along * OVERRUN
	var across := along.cross(Vector3.UP)
	var half := WIDTH / 2.0
	var y := HEIGHT + STEP * float(layer)
	var length := start.distance_to(end)
	var steps := maxi(1, int(ceil(length / 0.5)))
	var u0 := CellHash.of(from.x, from.y, map_seed, index) * 9.0
	var rows: Array = []
	for k in steps + 1:
		var t := float(k) / float(steps)
		var centre := start.lerp(end, t)
		var left := half + (CellHash.of(k, index, map_seed, 1) - 0.5) * 0.012
		var right := half + (CellHash.of(k, index, map_seed, 2) - 0.5) * 0.012
		rows.append([centre + across * left, centre - across * right, u0 + length * t])
	for k in steps:
		_quad(surface, rows[k], rows[k + 1], y)
	var p: Array = [rows[0][0], rows[0][1], rows[1][1]]
	var facing := signf((p[1] - p[0]).cross(p[2] - p[0]).y)
	_torn_end(surface, rows[0], -along, along, y, facing, index + map_seed * 7, 3)
	_torn_end(surface, rows[steps], along, along, y, facing, index + map_seed * 7, 4)


static func _quad(surface: SurfaceTool, a: Array, b: Array, y: float) -> void:
	var points := [a[0], a[1], b[1], b[0]]
	var uvs := [Vector2(a[2], 1.0), Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(b[2], 1.0)]
	for i in [0, 1, 2, 0, 2, 3]:
		_vertex(surface, points[i], uvs[i], y)


## A torn end on a strip's edge row: five ragged points pushed out along `out`, joined to
## the edge by a row of quads so no triangle folds over. Each triangle is wound to match
## `facing` (the sign of the strip's own normal.y), so both ends face the way the strip does.
## The UVs follow the points along the strip (`forward`), so the end has real tangents.
static func _torn_end(
	surface: SurfaceTool,
	edge: Array,
	out: Vector3,
	forward: Vector3,
	y: float,
	facing: float,
	key: int,
	salt: int
) -> void:
	var left: Vector3 = edge[0]
	var right: Vector3 = edge[1]
	var middle := (left + right) / 2.0
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for j in 7:
		var on_edge := left.lerp(right, float(j) / 6.0)
		inner.append(on_edge)
		var reach := 0.0 if j == 0 or j == 6 else 0.015 + CellHash.of(key, j, salt, 5) * 0.06
		outer.append(on_edge + out * reach)
	for j in 6:
		_end_triangle(
			surface, [inner[j], inner[j + 1], outer[j + 1]], edge, middle, forward, y, facing
		)
		_end_triangle(surface, [inner[j], outer[j + 1], outer[j]], edge, middle, forward, y, facing)


static func _end_triangle(
	surface: SurfaceTool,
	points: Array,
	edge: Array,
	middle: Vector3,
	forward: Vector3,
	y: float,
	facing: float
) -> void:
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if absf(normal.y) < 1e-8:
		return
	if signf(normal.y) != facing:
		points = [points[0], points[2], points[1]]
	var left: Vector3 = edge[0]
	var across: Vector3 = (edge[1] - left).normalized()
	for point: Vector3 in points:
		var v := 1.0 - (point - left).dot(across) / WIDTH
		var uv := Vector2(edge[2] + (point - middle).dot(forward), clampf(v, 0.0, 1.0))
		_vertex(surface, point, uv, y)


static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, y: float) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(Vector3(point.x, y, point.z))
