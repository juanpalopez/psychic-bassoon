## Masking tape along a map's roads, as one mesh. Each stretch of road cells that no earlier
## route has taped gets strips, one per straight run, from the taped cell before it (where it
## leaves a road) to the taped cell after it (where it joins one), so a feeder and a detour
## both get tape. Strips run a little past their ends so they overlap at the corners, and
## have torn ends and a slight wobble taken from CellHash. UV.x runs along a strip in
## metres, UV.y across it from 0 to 1.
class_name TapeBuilder
extends RefCounted

const WIDTH := 0.84
## The height of the first strip; later strips lie a step higher where they overlap, all
## under Board.ROAD_HEIGHT. A step is a few depth-buffer steps at the camera's distance.
const HEIGHT := 0.004
const STEP := 0.0018
const LAYERS := 3
## How far a strip runs past its last cell, and back from a road's first cell into the ink.
const OVERRUN := 0.46
const LEAD_IN := 0.8


## The tape for `routes` (lists of cells) on the board of `map_seed`.
static func build(routes: Array, map_seed: int) -> ArrayMesh:
	var taped := {}
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
				_strip(surface, cells[run[0]], cells[run[1]], lead, strip, map_seed)
				strip += 1
		for cell in route:
			taped[cell] = true
	surface.generate_tangents()
	return surface.commit()


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
	surface: SurfaceTool, from: Vector2i, to: Vector2i, lead: float, index: int, map_seed: int
) -> void:
	var start := BoardSpace.cell_to_world(from.x, from.y)
	var end := BoardSpace.cell_to_world(to.x, to.y)
	var along := (end - start).normalized() if from != to else Vector3.RIGHT
	start -= along * lead
	end += along * OVERRUN
	var across := along.cross(Vector3.UP)
	var half := WIDTH / 2.0
	var y := HEIGHT + STEP * float(index % LAYERS)
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
	_torn_end(surface, rows[0], -along, along, y, index + map_seed * 7, 3)
	_torn_end(surface, rows[steps], along, along, y, index + map_seed * 7, 4)


static func _quad(surface: SurfaceTool, a: Array, b: Array, y: float) -> void:
	var points := [a[0], a[1], b[1], b[0]]
	var uvs := [Vector2(a[2], 1.0), Vector2(a[2], 0.0), Vector2(b[2], 0.0), Vector2(b[2], 1.0)]
	for i in [0, 1, 2, 0, 2, 3]:
		_vertex(surface, points[i], uvs[i], y)


## A torn end on a strip's edge row: a fan of five ragged points pushed out along `out`. The
## UVs follow the points along the strip (`forward`), so the fan has real tangents.
static func _torn_end(
	surface: SurfaceTool, edge: Array, out: Vector3, forward: Vector3, y: float, key: int, salt: int
) -> void:
	var left: Vector3 = edge[0]
	var right: Vector3 = edge[1]
	var u: float = edge[2]
	var middle := (left + right) / 2.0
	var centre := middle + out * 0.03
	var fringe: Array[Vector3] = [left]
	for j in range(1, 6):
		var t := float(j) / 6.0
		fringe.append(left.lerp(right, t) + out * (0.015 + CellHash.of(key, j, salt, 5) * 0.06))
	fringe.append(right)
	for j in fringe.size() - 1:
		for point: Vector3 in [centre, fringe[j], fringe[j + 1]]:
			var v := 1.0 - (point - left).dot((right - left).normalized()) / WIDTH
			var uv := Vector2(u + (point - middle).dot(forward), clampf(v, 0.0, 1.0))
			_vertex(surface, point, uv, y)


static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, y: float) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(Vector3(point.x, y, point.z))
