## The road beds and the bridges of the diorama (#325), built once from the map at load time.
##
## The bed follows the sim's routes (`GameState.routes`): their points are the truth for where
## foes walk, cell centres on the grid path today and the curves of #321 later. For drawing only,
## each route's polyline is rounded (corner cutting) and thinned, which keeps it inside the road
## cells either way, and a road carries on past the board edge it enters from. A later route (the
## feeder) is drawn only where it leaves the roads drawn before it, so it ends where it joins the
## main road; the lips of both beds open there, and the main road ends on a round flagstone yard
## under the Heartstone. Over each of `map.bridges` the bed stops; the bridge cells of one
## crossing (a bridge per wet road cell, so a river two cells wide has two side by side) carry
## one plank-and-rope bridge from bank to bank (with trestle legs where the ground under it is a
## gorge).
##
## `build` returns a node with two meshes, so two draw calls: the bed (one surface for every
## route) and the bridges (one surface for every bridge). It reads the map and the routes only,
## takes the terrain's top from `height_fn`, and every random-looking choice comes from
## `CellHash` on the map's seed, so the same map always looks the same.
class_name RoadBedBuilder
extends RefCounted

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const FORK := preload("res://content/valley/road_bed_rules.gd")
## Salts for `CellHash`, so the bed's edges and the planks draw different values.
const SALT_LEFT := 11
const SALT_RIGHT := 12
const SALT_PLANK := 13
## How far back inside a piece its end samples the ground (cells), so a cut end on a cell's edge
## reads the cell it belongs to.
const SAMPLE_INSET := 0.02


## The bed and the bridges for `map`, along `routes` (the game's `Route`s, `routes[0]` the main
## road). `height_fn(cell: Vector2i) -> float` gives the terrain's top at any cell, on or off the
## board, in world units. The node holds `RoadBed` and `Bridges` (MeshInstance3D each).
static func build(map: GameMap, routes: Array[Route], height_fn: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "RoadBeds"
	var bed := MeshInstance3D.new()
	bed.name = "RoadBed"
	bed.mesh = bed_mesh(map, routes, height_fn)
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bed)
	var bridges := MeshInstance3D.new()
	bridges.name = "Bridges"
	bridges.mesh = bridge_mesh(map, height_fn)
	root.add_child(bridges)
	return root


## The drawn middle line of every stretch of road, in sim cells (x across, y down; a cell's
## centre is col + 0.5): the main road first, then each later route from its spawn to where it
## joins a road drawn before it. Each starts `ROAD_RUN_OUT` cells off the board. The scenery
## (#326) keeps off these lines.
static func centrelines(routes: Array[Route], coarse: bool = false) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var drawn: Array[PackedVector2Array] = []
	for route in routes:
		var raw := _points(route)
		for run in _new_runs(raw, drawn):
			var points := raw.slice(run.x, run.y + 1)
			if run.x == 0:
				var out := _run_out(raw)
				out.append_array(points)
				points = out
			lines.append(_thin(_rounded(points), coarse))
		drawn.append(raw)
	return lines


## Where the bridge over `bridge` lies, in sim cells: its deck from one end to the other, and
## from one row of posts to the other (`road_width` is the map's, `GameMap.road_width`). A
## crossing of several bridge cells is the union of theirs.
static func deck_rect(bridge: GameMap.Bridge, road_width: float = LOOKS.ROAD_WIDTH) -> Rect2:
	var centre := Vector2(bridge.cell) + Vector2(0.5, 0.5)
	var half := Vector2(
		LOOKS.BRIDGE_SPAN / 2.0, RoadDimensions.post_out(road_width) + LOOKS.POST_SIZE / 2.0
	)
	if not bridge.horizontal:
		half = Vector2(half.y, half.x)
	return Rect2(centre - half, half * 2.0)


## The top of a bridge's deck, in world units: where foes and guards stand on the bridge cell,
## `TerrainField.ROAD_HEIGHT` above the higher of its two banks (the same height the field's
## `surface_height` gives a road cell, on the valley floor). The banks are the first cells either
## way along the road that are not below the valley floor, so every cell of a crossing over a
## wide river stands at the same height.
static func deck_top(bridge: GameMap.Bridge, height_fn: Callable) -> float:
	var step := Vector2i(1, 0) if bridge.horizontal else Vector2i(0, 1)
	return (
		maxf(_bank(bridge.cell, -step, height_fn), _bank(bridge.cell, step, height_fn))
		+ (TerrainField.ROAD_HEIGHT)
	)


## The map's bridges as crossings: each crossing's bridge cells, side by side along the road, in
## order. One bridge is drawn over each crossing.
static func crossings(map: GameMap) -> Array[Array]:
	var found: Array[Array] = []
	var taken := {}
	for bridge in map.bridges:
		if taken.has(bridge.cell):
			continue
		var step := Vector2i(1, 0) if bridge.horizontal else Vector2i(0, 1)
		var first := bridge
		while true:
			var before := _bridge_at(map, first.cell - step, bridge.horizontal)
			if before == null:
				break
			first = before
		var run: Array[GameMap.Bridge] = [first]
		while true:
			var after := _bridge_at(map, run[run.size() - 1].cell + step, bridge.horizontal)
			if after == null:
				break
			run.append(after)
		for cell_bridge in run:
			taken[cell_bridge.cell] = true
		found.append(run)
	return found


## The road bed: every centreline as a ribbon with lips, broken over the bridges, and the yard
## under the Heartstone. One surface in `road_bed.gdshader`.
static func bed_mesh(map: GameMap, routes: Array[Route], height_fn: Callable) -> ArrayMesh:
	# a forked map (#481) thins its beds further to stay inside the terrain's triangle cap
	var lines := centrelines(routes, not map.forks.is_empty())
	var cuts: Array[Rect2] = []
	for bridge in map.bridges:
		cuts.append(_bed_cut(bridge, map.road_width))
	var yard := heart_yard(map, height_fn)
	var ribbon := Ribbon.new()
	for i in lines.size():
		var others: Array[PackedVector2Array] = []
		for j in lines.size():
			if j != i:
				others.append(lines[j])
		var drop := 0.0 if i == 0 else LOOKS.JOIN_DROP
		var along := 0.0
		for piece in _clip_out(lines[i], cuts):
			along = _ribbon(
				ribbon, piece, i, along, drop, others, yard, map.seed, map.road_width, height_fn
			)
	if yard.z > 0.0:
		var ground := float(height_fn.call(map.path[map.path.size() - 1]))
		_yard(
			ribbon, yard, ground + LOOKS.BED_LIFT - LOOKS.JOIN_DROP, ground, lines, map.road_width
		)
	return ribbon.commit(bed_material())


## The road bed's material: `road_bed.gdshader` in the diorama's palette.
static func bed_material() -> ShaderMaterial:
	var made := PaperLook.material("road_bed")
	made.set_shader_parameter("road_light", TerrainPalette.ROAD)
	made.set_shader_parameter("road_edge", TerrainPalette.ROAD_EDGE)
	made.set_shader_parameter("joint_colour", TerrainPalette.ROAD_JOINT)
	made.set_shader_parameter("lip_colour", TerrainPalette.ROAD_LIP)
	return made


## The bridges, one surface of faceted planks, posts and ropes in the painted paper the ground
## and the props share (`painted.gdshader`, its colours linear in the vertex colours).
static func bridge_mesh(map: GameMap, height_fn: Callable) -> ArrayMesh:
	var mesh := FacetMesh.new()
	for run in crossings(map):
		_bridge(mesh, run, map.seed, map.road_width, height_fn)
	return mesh.commit(PaperLook.material("painted"))


## The first cell from `cell` in the direction `step` that is not below the valley floor, and
## its top (at most `BRIDGE_MAX_CELLS` cells on; the last one looked at past that).
static func _bank(cell: Vector2i, step: Vector2i, height_fn: Callable) -> float:
	var top := float(height_fn.call(cell + step))
	for k in range(2, LOOKS.BRIDGE_MAX_CELLS + 2):
		if top >= 0.0:
			break
		top = float(height_fn.call(cell + step * k))
	return top


## The bridge on `cell` running the same way, or null.
static func _bridge_at(map: GameMap, cell: Vector2i, horizontal: bool) -> GameMap.Bridge:
	for bridge in map.bridges:
		if bridge.cell == cell and bridge.horizontal == horizontal:
			return bridge
	return null


## A route's points, in sim cells.
static func _points(route: Route) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in route.xs.size():
		points.append(Vector2(route.xs[i], route.ys[i]))
	return points


## The stretches of `points` that lie on none of the `drawn` lines, as (first, last) index pairs,
## each widened by one point either side where it meets a drawn road (so it reaches the join).
static func _new_runs(
	points: PackedVector2Array, drawn: Array[PackedVector2Array]
) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var start := -1
	for k in points.size() + 1:
		var on := k == points.size() or _on_any(points[k], drawn)
		if not on and start < 0:
			start = k
		elif on and start >= 0:
			runs.append(Vector2i(maxi(start - 1, 0), mini(k, points.size() - 1)))
			start = -1
	return runs


static func _on_any(point: Vector2, lines: Array[PackedVector2Array]) -> bool:
	for line in lines:
		if _distance_to_line(point, line) < LOOKS.JOIN_EPSILON:
			return true
	return false


static func _distance_to_line(point: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for k in line.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, line[k], line[k + 1])
		best = minf(best, point.distance_to(closest))
	if line.size() == 1:
		best = point.distance_to(line[0])
	return best


## Points from `ROAD_RUN_OUT` cells off the board up to (not including) the route's spawn point,
## straight back along the way the route enters.
static func _run_out(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return out
	var back := (points[0] - points[1]).normalized()
	var steps := int(ceil(LOOKS.ROAD_RUN_OUT / LOOKS.ROAD_STEP))
	for k in range(steps, 0, -1):
		out.append(points[0] + back * LOOKS.ROAD_STEP * float(k))
	return out


## Chaikin's corner cutting, keeping both ends where they are.
static func _rounded(points: PackedVector2Array) -> PackedVector2Array:
	var line := points
	for _pass in LOOKS.ROAD_SMOOTH_PASSES:
		if line.size() < 3:
			return line
		var cut := PackedVector2Array([line[0]])
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			if k > 0:
				cut.append(a.lerp(b, 0.25))
			if k < line.size() - 2:
				cut.append(a.lerp(b, 0.75))
		cut.append(line[line.size() - 1])
		line = cut
	return line


## The line with the points it does not need dropped: at most `ROAD_STEP` apart on the straight,
## and as close as it takes to bend by no more than `ROAD_BEND_DEGREES` a point.
static func _thin(points: PackedVector2Array, coarse: bool = false) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var step: float = FORK.FORK_ROAD_STEP if coarse else LOOKS.ROAD_STEP
	var bend := deg_to_rad(FORK.FORK_ROAD_BEND_DEGREES if coarse else LOOKS.ROAD_BEND_DEGREES)
	var kept := PackedVector2Array([points[0]])
	for k in range(1, points.size() - 1):
		var last := kept[kept.size() - 1]
		var ahead := points[k + 1] - points[k]
		var here := points[k] - last
		if points[k + 1].distance_to(last) > step or absf(here.angle_to(ahead)) > bend:
			kept.append(points[k])
	kept.append(points[points.size() - 1])
	return kept


## Where the bed stops for a bridge: the bridge cell from one bank to the other, and wide
## enough across that no bed edge crosses it (the deck covers the bed's cut ends on the banks).
static func _bed_cut(bridge: GameMap.Bridge, road_width: float) -> Rect2:
	var cell := Rect2(Vector2(bridge.cell), Vector2.ONE)
	var across := RoadDimensions.bed_cut_across(road_width)
	if bridge.horizontal:
		return cell.grow_individual(0.0, across, 0.0, across)
	return cell.grow_individual(across, 0.0, across, 0.0)


## The pieces of `line` outside every rectangle in `cuts`, each cut exactly at a rectangle's edge.
static func _clip_out(line: PackedVector2Array, cuts: Array[Rect2]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var piece := PackedVector2Array()
	for k in line.size() - 1:
		var a := line[k]
		var b := line[k + 1]
		var inside: Array[Vector2] = []
		for rect in cuts:
			var span := _segment_in_rect(a, b, rect)
			if span.x < span.y:
				inside.append(span)
		inside.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var t := 0.0
		for span in inside:
			if span.x > t:
				if piece.is_empty():
					piece.append(a.lerp(b, t))
				piece.append(a.lerp(b, span.x))
			if piece.size() >= 2:
				pieces.append(piece)
			piece = PackedVector2Array()
			t = maxf(t, span.y)
		if t < 1.0:
			if piece.is_empty():
				piece.append(a.lerp(b, t))
			piece.append(b)
	if piece.size() >= 2:
		pieces.append(piece)
	return pieces


## The share of the segment from `a` to `b` inside `rect`, as (enter, leave); empty when
## enter >= leave (Liang-Barsky).
static func _segment_in_rect(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var enter := 0.0
	var leave := 1.0
	var d := b - a
	for axis in 2:
		var low := rect.position[axis]
		var high := rect.end[axis]
		if absf(d[axis]) < 1e-9:
			if a[axis] < low or a[axis] > high:
				return Vector2(1.0, 0.0)
			continue
		var t0 := (low - a[axis]) / d[axis]
		var t1 := (high - a[axis]) / d[axis]
		enter = maxf(enter, minf(t0, t1))
		leave = minf(leave, maxf(t0, t1))
	return Vector2(clampf(enter, 0.0, 1.0), clampf(leave, 0.0, 1.0))


## The round yard the main road ends on, as (x, y) its middle in sim cells and z its radius
## (0 when the map has no road). Where the Heartstone's whole block stands at the road's level it
## is a flagstone yard under the block (`HEART_YARD_RADIUS` round its middle); where part of the
## block stands higher, a round end to the road in its last cell (`HEART_CAP_RADIUS`), so the
## yard never runs into a terrace.
static func heart_yard(map: GameMap, height_fn: Callable) -> Vector3:
	if map.path.is_empty():
		return Vector3.ZERO
	var last := map.path[map.path.size() - 1]
	var level := float(height_fn.call(last))
	var block := map.heartstone
	var flat := block.has_point(last)
	for row in range(block.position.y, block.end.y):
		for col in range(block.position.x, block.end.x):
			if absf(float(height_fn.call(Vector2i(col, row))) - level) > 1e-4:
				flat = false
	if flat:
		var middle := Vector2(block.position) + Vector2(block.size) / 2.0
		return Vector3(middle.x, middle.y, RoadDimensions.heart_yard_radius(map.road_width))
	return Vector3(
		float(last.x) + 0.5, float(last.y) + 0.5, RoadDimensions.heart_cap_radius(map.road_width)
	)


## One piece of a centreline as a ribbon: six points across (outer edge, lip crest, bed edge on
## each side), its lips flattened where another road or the yard opens into it. Returns the
## distance along the line at the piece's end, for the next piece's UVs.
static func _ribbon(
	ribbon: Ribbon,
	piece: PackedVector2Array,
	line: int,
	along: float,
	drop: float,
	others: Array[PackedVector2Array],
	yard: Vector3,
	map_seed: int,
	road_width: float,
	height_fn: Callable
) -> float:
	var half := road_width / 2.0
	var open_reach := half + LOOKS.ROAD_WOBBLE
	var first := ribbon.vertex_count()
	var count := piece.size()
	for k in count:
		var p := piece[k]
		if k > 0:
			along += p.distance_to(piece[k - 1])
		var tangent := (piece[mini(k + 1, count - 1)] - piece[maxi(k - 1, 0)]).normalized()
		var left := Vector2(tangent.y, -tangent.x)
		# a piece cut at a bridge ends exactly on the gorge cell's edge: take the ground a hair
		# back inside the piece, on the bank, not in the gorge
		var probe := p + tangent * SAMPLE_INSET if k == 0 else p
		if k == count - 1 and count > 1:
			probe = p - tangent * SAMPLE_INSET
		var ground := float(height_fn.call(Vector2i(floori(probe.x), floori(probe.y))))
		var bed := ground + LOOKS.BED_LIFT - drop
		var widths: Array[float] = [
			half + _wobble(along, line, map_seed, SALT_LEFT),
			half + _wobble(along, line, map_seed, SALT_RIGHT),
		]
		# across from the left outer edge to the right one: edge, lip crest, bed edge, then back out
		var across: Array[float] = [
			widths[0],
			widths[0] - LOOKS.LIP_CREST,
			widths[0] - LOOKS.LIP_WIDTH,
			-(widths[1] - LOOKS.LIP_WIDTH),
			-(widths[1] - LOOKS.LIP_CREST),
			-widths[1],
		]
		var open_left := _opens(p + left * across[1], others, yard, open_reach)
		var open_right := _opens(p + left * across[4], others, yard, open_reach)
		var heights: Array[float] = [
			bed if open_left else ground + LOOKS.EDGE_LIFT,
			bed if open_left else bed + LOOKS.LIP_HEIGHT,
			bed,
			bed,
			bed if open_right else bed + LOOKS.LIP_HEIGHT,
			bed if open_right else ground + LOOKS.EDGE_LIFT,
		]
		for j in 6:
			var width: float = widths[0] if across[j] > 0.0 else widths[1]
			ribbon.add(_world(p + left * across[j], heights[j]), Vector2(along, across[j] / width))
	for k in count - 1:
		for j in 5:
			var a := first + k * 6 + j
			var b := a + 6
			ribbon.quad(a, a + 1, b + 1, b)
	return along


## True when the lip at `crest` opens: another road or the Heartstone's yard comes in there.
static func _opens(
	crest: Vector2, others: Array[PackedVector2Array], yard: Vector3, reach: float
) -> bool:
	if crest.distance_to(Vector2(yard.x, yard.y)) < yard.z:
		return true
	return _distance_to_lines(crest, others) < reach


static func _distance_to_lines(point: Vector2, lines: Array[PackedVector2Array]) -> float:
	var best := INF
	for line in lines:
		best = minf(best, _distance_to_line(point, line))
	return best


## A smooth wander of the bed's edge, at most `ROAD_WOBBLE` either way.
static func _wobble(along: float, line: int, map_seed: int, salt: int) -> float:
	var at := along / LOOKS.ROAD_WOBBLE_LENGTH
	var knot := floori(at)
	var t := at - float(knot)
	t = t * t * (3.0 - 2.0 * t)
	var a := CellHash.of(knot, line, map_seed, salt)
	var b := CellHash.of(knot + 1, line, map_seed, salt)
	return (lerpf(a, b, t) - 0.5) * 2.0 * LOOKS.ROAD_WOBBLE


## The round yard at the Heartstone (`heart_yard`): a disc of bed with a lip round it, the lip
## open where a road comes in.
static func _yard(
	ribbon: Ribbon,
	yard: Vector3,
	top: float,
	ground: float,
	lines: Array[PackedVector2Array],
	road_width: float
) -> void:
	var centre := Vector2(yard.x, yard.y)
	var radius := yard.z
	var segments := LOOKS.HEART_YARD_SEGMENTS
	var middle := ribbon.vertex_count()
	ribbon.add(_world(centre, top), Vector2(0.0, 0.0))
	var reach := road_width / 2.0 + LOOKS.ROAD_WOBBLE
	for s in segments:
		var angle := TAU * float(s) / float(segments)
		var out := Vector2(cos(angle), sin(angle))
		var crest := centre + out * (radius - LOOKS.LIP_CREST)
		var open := _distance_to_lines(crest, lines) < reach
		var rings := [
			[radius - LOOKS.LIP_WIDTH, top],
			[radius - LOOKS.LIP_CREST, top if open else top + LOOKS.LIP_HEIGHT],
			[radius, top if open else ground + LOOKS.EDGE_LIFT],
		]
		for ring: Array in rings:
			var r: float = ring[0]
			ribbon.add(_world(centre + out * r, ring[1]), Vector2(0.0, r / radius))
	for s in segments:
		var a := middle + 1 + s * 3
		var b := middle + 1 + ((s + 1) % segments) * 3
		ribbon.triangle(middle, a, b)
		for j in 2:
			ribbon.quad(a + j, b + j, b + j + 1, a + j + 1)


## A sim position (cells) at a world height.
static func _world(at: Vector2, height: float) -> Vector3:
	var world := BoardSpace.point_to_world(at.x, at.y)
	return Vector3(world.x, height, world.z)


## One bridge over a crossing's cells (`run`, in order along the road): planks across the span,
## a post at each corner on the banks, a hand rope along each side with thin hangers to the deck,
## and trestle legs under each cell over a gorge.
static func _bridge(
	mesh: FacetMesh, run: Array, map_seed: int, road_width: float, height_fn: Callable
) -> void:
	var first: GameMap.Bridge = run[0]
	var last: GameMap.Bridge = run[run.size() - 1]
	var centre := (Vector2(first.cell) + Vector2(last.cell)) / 2.0 + Vector2(0.5, 0.5)
	var axis := Vector2(1.0, 0.0) if first.horizontal else Vector2(0.0, 1.0)
	var across := Vector2(-axis.y, axis.x)
	var span := LOOKS.BRIDGE_SPAN + float(run.size() - 1)
	var top := deck_top(first, height_fn)
	var cell := first.cell
	var deck := RoadDimensions.deck_width(road_width)
	var along_3 := _direction(axis)
	var across_3 := _direction(across)
	var flat := Basis(along_3, Vector3.UP, across_3)
	# planks: a little apart, each its own tone, length and slight turn, about as many to a cell
	# as on a one-cell bridge
	var planks := int(floor(float(LOOKS.PLANKS) * span / LOOKS.BRIDGE_SPAN + 0.5))
	var pitch := span / float(planks)
	for k in planks:
		var s := (float(k) + 0.5) / float(planks)
		var at := centre + axis * (s - 0.5) * span
		var y := top - LOOKS.PLANK_THICKNESS / 2.0
		var tone := (CellHash.of(cell.x, cell.y, k, map_seed + SALT_PLANK) - 0.5) * 2.0
		var colour := TerrainPalette.PLANK.darkened(maxf(0.0, -tone) * LOOKS.PLANK_TONE)
		colour = colour.lightened(maxf(0.0, tone) * LOOKS.PLANK_TONE)
		var turn := (CellHash.of(k, cell.x, cell.y, map_seed + SALT_PLANK + 1) - 0.5) * 0.08
		var length := deck * (0.96 + 0.06 * CellHash.of(k, cell.y, cell.x, map_seed))
		var basis := Basis(Vector3.UP, turn) * flat
		var size := Vector3(pitch * LOOKS.PLANK_FILL, LOOKS.PLANK_THICKNESS, length)
		mesh.box(_world(at, y), basis, size, colour)
	# two ropes under the plank ends, pulled taut
	for side: float in [-1.0, 1.0]:
		var under := across * side * (deck / 2.0 - 0.06)
		_rope(mesh, centre + under, axis, span, top - LOOKS.PLANK_THICKNESS, 0.0)
	# posts on the banks and the hand ropes between them
	for side: float in [-1.0, 1.0]:
		var out := across * side * RoadDimensions.post_out(road_width)
		for end: float in [-1.0, 1.0]:
			var foot := centre + axis * end * span / 2.0 + out
			var bank := float(height_fn.call(Vector2i(floori(foot.x), floori(foot.y))))
			var low := minf(bank, top) - 0.05
			var high := top + LOOKS.POST_HEIGHT
			var size := Vector3(LOOKS.POST_SIZE, high - low, LOOKS.POST_SIZE)
			mesh.box(_world(foot, (low + high) / 2.0), flat, size, TerrainPalette.POST, false)
		var rail := top + LOOKS.POST_HEIGHT - 0.04
		_rope(mesh, centre + out, axis, span, rail, LOOKS.ROPE_SAG)
		var hangers := LOOKS.HANGERS * run.size()
		for h in hangers:
			var s := (float(h) + 1.0) / float(hangers + 1)
			var at := centre + axis * (s - 0.5) * span
			var from := _world(at + out, rail - _sag(s, LOOKS.ROPE_SAG))
			var edge := at + across * side * (deck / 2.0 - 0.02)
			var to := _world(edge, top)
			mesh.beam(from, to, LOOKS.HANGER_THICKNESS, TerrainPalette.ROPE)
	for bridge: GameMap.Bridge in run:
		var floor_y := float(height_fn.call(bridge.cell))
		if top - floor_y > LOOKS.TRESTLE_MIN_DROP:
			var middle := Vector2(bridge.cell) + Vector2(0.5, 0.5)
			_trestles(
				mesh,
				middle,
				axis,
				across,
				top,
				floor_y,
				flat,
				RoadDimensions.trestle_out(road_width)
			)


## A rope from one end of the span to the other along `axis`, starting `height` up and sagging
## by `sag` in the middle.
static func _rope(
	mesh: FacetMesh, middle: Vector2, axis: Vector2, span: float, height: float, sag: float
) -> void:
	var previous := Vector3.ZERO
	for k in LOOKS.ROPE_SEGMENTS + 1:
		var s := float(k) / float(LOOKS.ROPE_SEGMENTS)
		var at := _world(middle + axis * (s - 0.5) * span, height - _sag(s, sag))
		if k > 0:
			mesh.beam(previous, at, LOOKS.ROPE_THICKNESS, TerrainPalette.ROPE)
		previous = at


## The legs and braces under a deck that stands over a gorge.
static func _trestles(
	mesh: FacetMesh,
	centre: Vector2,
	axis: Vector2,
	across: Vector2,
	top: float,
	floor_y: float,
	flat: Basis,
	out: float
) -> void:
	for s: float in LOOKS.TRESTLE_AT:
		var at := centre + axis * (s - 0.5) * LOOKS.BRIDGE_SPAN
		var under := top - LOOKS.PLANK_THICKNESS
		var legs: Array[Vector3] = []
		for side: float in [-1.0, 1.0]:
			var foot := at + across * side * out
			var height := under - floor_y
			var size := Vector3(LOOKS.TRESTLE_SIZE, height, LOOKS.TRESTLE_SIZE)
			mesh.box(
				_world(foot, floor_y + height / 2.0), flat, size, TerrainPalette.TRESTLE, false
			)
			legs.append(_world(foot, floor_y))
			legs.append(_world(foot, under))
		mesh.beam(legs[0], legs[3], LOOKS.TRESTLE_SIZE * 0.6, TerrainPalette.TRESTLE)
		mesh.beam(legs[1], legs[2], LOOKS.TRESTLE_SIZE * 0.6, TerrainPalette.TRESTLE)


## How far a sagging line hangs below its ends a share `s` of the way along.
static func _sag(s: float, sag: float) -> float:
	return sag * 4.0 * s * (1.0 - s)


## A direction in sim cells as a world direction on the ground.
static func _direction(sim: Vector2) -> Vector3:
	return (
		(BoardSpace.point_to_world(sim.x, sim.y) - BoardSpace.point_to_world(0.0, 0.0)).normalized()
	)


## The surface of the bed while it is built: shared vertices (positions and UVs, along and
## across) and the triangles between them.
class Ribbon:
	extends RefCounted
	var _vertices := PackedVector3Array()
	var _uvs := PackedVector2Array()
	var _indices := PackedInt32Array()

	func vertex_count() -> int:
		return _vertices.size()

	func add(at: Vector3, uv: Vector2) -> void:
		_vertices.append(at)
		_uvs.append(uv)

	## A triangle of three vertices, wound to face up (clockwise seen from above).
	func triangle(a: int, b: int, c: int) -> void:
		var normal := (_vertices[b] - _vertices[a]).cross(_vertices[c] - _vertices[a])
		if normal.y > 0.0:
			_indices.append_array([a, c, b])
		else:
			_indices.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		triangle(a, b, c)
		triangle(a, c, d)

	func triangle_count() -> int:
		return _indices.size() / 3

	## The surface, its triangles laid out corner by corner (unindexed, as every diorama mesh is,
	## so a face's three corners are three vertices in a row).
	func commit(material: Material) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if _indices.is_empty():
			return mesh
		var corners := PackedVector3Array()
		var uvs := PackedVector2Array()
		for i in _indices:
			corners.append(_vertices[i])
			uvs.append(_uvs[i])
		var normals := PackedVector3Array()
		normals.resize(corners.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = corners
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh
