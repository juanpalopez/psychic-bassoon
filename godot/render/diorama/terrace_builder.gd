## The terraces of the diorama: faceted grassy tops at each level of the field, and corrugated
## card cliffs with a dark soil lip down to the level below (`assets-src/diorama_lookdev`,
## `terraces2` and `wall_strip`), meshed in chunks so the camera culls what it does not see: small
## square chunks aligned to the map's cells over the map and the country near it, where the
## camera works, and one coarse chunk per side and corner out in the haze.
##
## The mesh is marching squares over the cell centres: each square between four centres is
## split into four triangles round its middle, and each triangle is cut along every terrace
## level that crosses it. A level's outline crosses an edge between two centres near the
## middle (hashed a little either way, so the outlines wobble), and the middle of a square is
## inside or out by how many of its corners are (hashed too, so corners chamfer at random). A
## guarded cell (a socket, the Heartstone, the road) keeps its square outline: no wobble on its
## edges, and the middle of a square follows the most guarded corner. Each cell's centre is
## thus always on its own level, at `TerrainField.level_height`. Where a cliff meets the river,
## the gorge bites a little into the bank. The colours (grass by terrace and noise, kraft and
## soil on the walls, the contact shading at the foot of each cliff in the alpha) are vertex
## colours, so one material and one draw call draw a chunk.
@tool
class_name TerraceBuilder
extends DioramaBuilder

## Cells on a side of a near chunk; its edges fall on multiples of it in map cells.
const CHUNK_CELLS := 16
## The near chunks cover the map grown to whole chunks with at least this many cells round it
## (32 by 20 gives x -16 to 48 and y -16 to 32); past them lie the coarse chunks.
const NEAR_CELLS := 12
## The key of a coarse chunk: this plus, across and in depth, 0 before the near chunks, 200
## after them, or 100 plus its piece alongside them.
const FAR_KEY := 1000
const FAR_CELLS_ALONG := 32
## How far an outline may wander from the middle of an edge (a share of the edge), and how far
## the middle of a square may move from its corners' share.
const EDGE_NOISE := 0.3
const CENTRE_NOISE := 0.25
## How far the gorge bites into an unguarded bank (a share of the edge).
const GORGE_WIDEN := 0.18
## The middle of a square that follows a guarded corner sits this close to the outline.
const GUARD_EPSILON := 0.02
## An outline crossing this close to the middle (a share of the way to the corner) is drawn
## through the middle itself, so a guarded corner is square and leaves no sliver of wall.
const MIDDLE_SNAP := 0.06
## The soil lip under the grass, in metres, and how far down a wall sinks into the level below.
const LIP := 0.08
const SINK := 0.03
## The corrugation: wall corners pushed up to `RIDGE` metres out of line (the lip less), by a
## noise this many metres between lattice points, so neighbouring facets catch the light apart.
const RIDGE := 0.06
const LIP_RIDGE := 0.35
const RIDGE_SPACING := 0.45
## The contact shading at the foot of a cliff (1 less this much) and on a wall's foot.
const FOOT_SHADE := 0.4
const WALL_FOOT_SHADE := 0.3
## A cliff this deep (metres) is at its darkest at the bottom.
const DEEP_WALL := 1.5
const SALT_EDGE := 711
const SALT_CENTRE := 712
const SALT_COLOUR := 713
const SALT_DRY := 714
const SALT_RIDGE_X := 715
const SALT_RIDGE_Z := 716
const SALT_FACET := 717
const SALT_KRAFT := 718
## Far from the map, flat ground is drawn as one quad over blocks of this many squares a side
## (the biggest that fits first), but never within `MERGE_KEEP` cells of the map. Blocks start
## on multiples of their size in map cells and every chunk edge is a multiple of 16, so a block
## never straddles two chunks.
const MERGE_TIERS: Array[int] = [8, 4, 2]
const MERGE_KEEP := 3
## From this many cells past the map the cliffs are plainer.
const FAR_CELLS := 10
const CORNERS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const MIDDLE := Vector2(0.5, 0.5)

## The material every chunk wears (`Diorama` sets it; swap it for another vertex-colour look).
var material: Material
## How many chunk meshes the last build made.
var chunk_count: int = 0

var _field: TerrainField
var _w := 0
var _h := 0
## The world x and z of the field's first cell centre.
var _x0 := 0.0
var _z0 := 0.0
## The grass colour of each cell centre (sRGB), before its terrace shades it.
var _node_colour := PackedColorArray()
## Where each level outline crosses the edge from a centre to the next one across (x) and in
## depth (z), as a share of the edge from that centre.
var _cross_x := PackedFloat32Array()
var _cross_z := PackedFloat32Array()
var _buckets := {}


func build(field: TerrainField) -> void:
	clear()
	prepare(field)
	_buckets.clear()
	var done := PackedByteArray()
	done.resize(_w * _h)
	for tier in MERGE_TIERS:
		for bj in range(posmod(-field.origin.y, tier), _h - 1 - tier + 1, tier):
			for bi in range(posmod(-field.origin.x, tier), _w - 1 - tier + 1, tier):
				if _flat_block(bi, bj, tier, done):
					_block(bi, bj, tier, done)
	for j in _h - 1:
		for i in _w - 1:
			if done[j * _w + i] == 0:
				_square(i, j, _bucket(i, j))
	chunk_count = 0
	var keys := _buckets.keys()
	keys.sort()
	for key in keys:
		var bucket: MeshBucket = _buckets[key]
		var chunk: Vector2i = key
		if bucket.is_empty():
			continue
		# out in the haze, past the sun's shadow distance, a chunk casts no shadow
		add_mesh(chunk_name(key), bucket.to_mesh(), material, chunk.x < FAR_KEY)
		chunk_count += 1
	_buckets.clear()


## Reads the field: each centre's grass and where the outlines cross each edge. `build` calls
## it; a test calls it to mesh single squares with `square`.
func prepare(field: TerrainField) -> void:
	_field = field
	_w = field.size.x
	_h = field.size.y
	var first := field.cell_centre(field.origin)
	_x0 = first.x
	_z0 = first.z
	_prepare_nodes()
	_prepare_edges()


## The mesh of one square (first corner at field cell (i, j)) on its own, as `build` draws it
## outside the merged blocks. Call `prepare` first.
func square(i: int, j: int) -> MeshBucket:
	var bucket := MeshBucket.new()
	_square(i, j, bucket)
	return bucket


## The values of the middle of the square at field cell (i, j), one per level its corners
## stand on, low to high (for tests: they never rise, so the outlines nest).
func middle_values(i: int, j: int) -> PackedFloat32Array:
	var at := j * _w + i
	var nodes := PackedInt32Array([at, at + 1, at + _w + 1, at + _w])
	var levels := PackedInt32Array()
	var steps := PackedInt32Array()
	for node in nodes:
		levels.append(_field.levels[node])
		if not steps.has(_field.levels[node]):
			steps.append(_field.levels[node])
	steps.sort()
	return _middle_values(i, j, nodes, levels, steps)


## Whether the squares from field cell (bi, bj), `tier` on a side, are all on one level, not
## drawn yet, and far enough past the map to draw as one big quad.
func _flat_block(bi: int, bj: int, tier: int, done: PackedByteArray) -> bool:
	var level := _field.levels[bj * _w + bi]
	var keep := Rect2i(
		-MERGE_KEEP, -MERGE_KEEP, _field.map.cols + 2 * MERGE_KEEP, _field.map.rows + 2 * MERGE_KEEP
	)
	for j in range(bj, bj + tier + 1):
		for i in range(bi, bi + tier + 1):
			var at := j * _w + i
			if _field.levels[at] != level:
				return false
			if keep.has_point(_field.origin + Vector2i(i, j)):
				return false
			if i < bi + tier and j < bj + tier and done[at] != 0:
				return false
	return true


func _block(bi: int, bj: int, tier: int, done: PackedByteArray) -> void:
	var level := _field.levels[bj * _w + bi]
	var y := TerrainField.level_height(level)
	var span := float(tier)
	var corners: Array[Vector2] = [
		Vector2(0, 0), Vector2(span, 0), Vector2(span, span), Vector2(0, span)
	]
	var nodes := PackedInt32Array(
		[bj * _w + bi, bj * _w + bi + tier, (bj + tier) * _w + bi + tier, (bj + tier) * _w + bi]
	)
	var colours: Array[Color] = []
	for node in nodes:
		colours.append(Color(_terrace_shade(_node_colour[node], level).srgb_to_linear(), 1.0))
	_bucket(bi, bj).quad(
		_world(bi, bj, corners[0], y),
		_world(bi, bj, corners[1], y),
		_world(bi, bj, corners[2], y),
		_world(bi, bj, corners[3], y),
		Vector3.UP,
		colours[0],
		colours[1],
		colours[2],
		colours[3]
	)
	for j in range(bj, bj + tier):
		for i in range(bi, bi + tier):
			done[j * _w + i] = 1


## Whether the square from field cell (i, j) lies `FAR_CELLS` or more past the map, out in the
## haze, where its cliffs are drawn plainer (no lip strip, no lean).
func _is_far(i: int, j: int) -> bool:
	var cell := _field.origin + Vector2i(i, j)
	var map := _field.map
	var past := maxi(maxi(-cell.x, cell.x + 1 - map.cols), maxi(-cell.y, cell.y + 1 - map.rows))
	return past >= FAR_CELLS


## The chunk that holds the square whose first corner is `cell` (map cells) on a map of `size`:
## a near chunk (in chunk units, aligned to the map) or a coarse one (`FAR_KEY` plus its bands).
static func chunk_of(cell: Vector2i, size: Vector2i) -> Vector2i:
	var near := near_rect(size)
	if near.has_point(cell):
		return Vector2i(floori(cell.x / float(CHUNK_CELLS)), floori(cell.y / float(CHUNK_CELLS)))
	# a coarse chunk is a band past the near ones (0 before, 2 after, 1 alongside), cut along
	# its length every `FAR_CELLS_ALONG` cells so the camera culls most of it up close
	var key := Vector2i(FAR_KEY, FAR_KEY)
	for k in 2:
		if cell[k] < near.position[k]:
			key[k] += 0
		elif cell[k] >= near.end[k]:
			key[k] += 200
		else:
			key[k] += 100 + floori((cell[k] - near.position[k]) / float(FAR_CELLS_ALONG))
	return key


## The map cells the near chunks cover: the map grown by `NEAR_CELLS`, out to whole chunks.
static func near_rect(size: Vector2i) -> Rect2i:
	var low := Vector2i.ZERO
	var high := Vector2i.ZERO
	for k in 2:
		low[k] = floori(-NEAR_CELLS / float(CHUNK_CELLS)) * CHUNK_CELLS
		high[k] = ceili((size[k] + NEAR_CELLS) / float(CHUNK_CELLS)) * CHUNK_CELLS
	return Rect2i(low, high - low)


## The node name of a chunk: `Chunk_x_y` near the map, `Far_<band>_<band>` out in the haze.
static func chunk_name(key: Vector2i) -> String:
	if key.x >= FAR_KEY:
		return "Far_%d_%d" % [key.x - FAR_KEY, key.y - FAR_KEY]
	return "Chunk_%d_%d" % [key.x, key.y]


func _bucket(i: int, j: int) -> MeshBucket:
	var key := chunk_of(_field.origin + Vector2i(i, j), Vector2i(_field.map.cols, _field.map.rows))
	if not _buckets.has(key):
		_buckets[key] = MeshBucket.new()
	return _buckets[key]


func _prepare_nodes() -> void:
	_node_colour.resize(_w * _h)
	var map := _field.map
	for j in _h:
		for i in _w:
			var cell := _field.origin + Vector2i(i, j)
			var x := float(cell.x)
			var y := float(cell.y)
			var lush := _field.noise(x, y, 4.0, SALT_COLOUR)
			var dry := _field.noise(x, y, 6.5, SALT_DRY)
			var grass := TerrainPalette.GRASS_SHADE.lerp(TerrainPalette.GRASS, lush)
			grass = grass.lerp(TerrainPalette.GRASS_DRY, clampf(dry - 0.65, 0.0, 0.3))
			match map.region_at(cell) if map.in_bounds(cell) else GameMap.Region.MEADOW:
				GameMap.Region.FOREST:
					grass = grass.lerp(TerrainPalette.FOREST_FLOOR, 0.55)
				GameMap.Region.ROCKS:
					grass = grass.lerp(TerrainPalette.STONE, 0.5)
				GameMap.Region.DIRT:
					grass = grass.lerp(TerrainPalette.DIRT, 0.6)
			var facet := 0.94 + 0.12 * CellHash.of(cell.x, cell.y, _field.seed, SALT_FACET)
			_node_colour[j * _w + i] = Color(grass.r * facet, grass.g * facet, grass.b * facet)


func _prepare_edges() -> void:
	_cross_x.resize(_w * _h)
	_cross_z.resize(_w * _h)
	for j in _h:
		for i in _w:
			var at := j * _w + i
			if i + 1 < _w:
				_cross_x[at] = _crossing(at, at + 1, 0)
			if j + 1 < _h:
				_cross_z[at] = _crossing(at, at + _w, 1)


## Where every outline crosses the edge from node `a` to node `b`, as a share from `a`.
func _crossing(a: int, b: int, salt: int) -> float:
	if _field.guards[a] != TerrainField.GUARD_NONE or _field.guards[b] != TerrainField.GUARD_NONE:
		return 0.5
	var cell := _field.origin + Vector2i(a % _w, a / _w)
	var share := (
		0.5 + (CellHash.of(cell.x, cell.y, _field.seed, SALT_EDGE + salt) - 0.5) * EDGE_NOISE
	)
	var gorge_a := _field.levels[a] == TerrainField.GORGE
	var gorge_b := _field.levels[b] == TerrainField.GORGE
	if gorge_a and not gorge_b:
		share += GORGE_WIDEN
	elif gorge_b and not gorge_a:
		share -= GORGE_WIDEN
	return clampf(share, 0.1, 0.9)


## One square between the centres of field cells (i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1).
func _square(i: int, j: int, bucket: MeshBucket) -> void:
	var at := j * _w + i
	var nodes := PackedInt32Array([at, at + 1, at + _w + 1, at + _w])
	var levels := PackedInt32Array()
	for node in nodes:
		levels.append(_field.levels[node])
	var lo := levels[0]
	var hi := levels[0]
	for level in levels:
		lo = mini(lo, level)
		hi = maxi(hi, level)
	if lo == hi:
		var y := TerrainField.level_height(lo)
		var colours: Array[Color] = []
		for m in 4:
			colours.append(_top_colour(nodes, levels, CORNERS[m], lo))
		bucket.quad(
			_world(i, j, CORNERS[0], y),
			_world(i, j, CORNERS[1], y),
			_world(i, j, CORNERS[2], y),
			_world(i, j, CORNERS[3], y),
			Vector3.UP,
			colours[0],
			colours[1],
			colours[2],
			colours[3]
		)
		return
	# where the outlines cross the square's four edges (the same for every level)
	var edges: Array[Vector2] = [
		Vector2(_cross_x[nodes[0]], 0.0),
		Vector2(1.0, _cross_z[nodes[1]]),
		Vector2(_cross_x[nodes[3]], 1.0),
		Vector2(0.0, _cross_z[nodes[0]]),
	]
	# the levels its corners stand on, low to high: a cliff runs from each down to the one below
	var steps := PackedInt32Array()
	for level in levels:
		if not steps.has(level):
			steps.append(level)
	steps.sort()
	var middle := _middle_values(i, j, nodes, levels, steps)
	# the lowest level covers the whole square (the higher ones lie on it), so it is one quad
	_top(i, j, bucket, CORNERS, nodes, levels, steps[0])
	var far := _is_far(i, j)
	for m in 4:
		var n := (m + 1) % 4
		for s in steps.size():
			var level := steps[s]
			var centre_value: float = middle[s]
			var in_a := levels[m] >= level
			var in_b := levels[n] >= level
			var in_c := centre_value >= 0.5
			if not (in_a or in_b or in_c):
				break
			var to_a := _towards(centre_value, in_a, CORNERS[m])
			var to_b := _towards(centre_value, in_b, CORNERS[n])
			# walk round the triangle middle, a, b, collecting the inside and the crossings
			var poly: Array[Vector2] = []
			var crossings: Array[Vector2] = []
			if in_c:
				poly.append(MIDDLE)
			if in_c != in_a:
				poly.append(to_a)
				crossings.append(to_a)
			if in_a:
				poly.append(CORNERS[m])
			if in_a != in_b:
				poly.append(edges[m])
				crossings.append(edges[m])
			if in_b:
				poly.append(CORNERS[n])
			if in_b != in_c:
				poly.append(to_b)
				crossings.append(to_b)
			var covered := false
			if s + 1 < steps.size():
				var next := steps[s + 1]
				covered = levels[m] >= next and levels[n] >= next and float(middle[s + 1]) >= 0.5
			if s > 0 and poly.size() >= 3 and not covered:
				_top(i, j, bucket, poly, nodes, levels, level)
			if s > 0 and crossings.size() == 2:
				var outside := MIDDLE
				if in_c:
					outside = CORNERS[m] if not in_a else CORNERS[n]
				_wall(
					i,
					j,
					bucket,
					[crossings[0], crossings[1], outside],
					nodes,
					levels,
					Vector2i(level, steps[s - 1]),
					far
				)


## The value of the square's middle at each of `steps`: its corners' share, hashed
## a little, or just inside or outside to follow its most guarded corners; never rising with
## the level, so the outlines nest.
func _middle_values(
	i: int, j: int, nodes: PackedInt32Array, levels: PackedInt32Array, steps: PackedInt32Array
) -> PackedFloat32Array:
	var guard := 0
	for node in nodes:
		guard = maxi(guard, _field.guards[node])
	var cell := _field.origin + Vector2i(i, j)
	var wobble := (CellHash.of(cell.x, cell.y, _field.seed, SALT_CENTRE) - 0.5) * CENTRE_NOISE
	var values := PackedFloat32Array([1.0])
	for s in range(1, steps.size()):
		var inside := 0
		var guarded_in := 0
		var guarded_out := 0
		var bridged_out := 0
		for m in 4:
			var is_in := levels[m] >= steps[s]
			inside += 1 if is_in else 0
			if guard > 0 and _field.guards[nodes[m]] == guard:
				guarded_in += 1 if is_in else 0
				guarded_out += 0 if is_in else 1
				bridged_out += 1 if not is_in and levels[m] == TerrainField.GORGE else 0
		var value := float(inside) / 4.0 + wobble
		if guarded_in > 0 and guarded_out == 0:
			value = 0.5 + GUARD_EPSILON
		elif guarded_in == inside and guarded_in > 0 and guarded_out == bridged_out:
			# a road cell beside a bridge over the gorge, nothing else on the floor (a river two
			# cells wide): the outline runs through the middle, so both stay square
			value = 0.5 + GUARD_EPSILON
		elif guarded_out > 0 and guarded_in == 0:
			value = 0.5 - GUARD_EPSILON
		values.append(minf(values[values.size() - 1], value))
	return values


## Where the outline crosses from the middle (value `centre`) toward a corner (inside or not);
## the middle itself when both are on the same side (unused then).
func _towards(centre: float, corner_in: bool, corner: Vector2) -> Vector2:
	var corner_value := 1.0 if corner_in else 0.0
	if is_equal_approx(centre, corner_value):
		return MIDDLE
	var share := clampf((centre - 0.5) / (centre - corner_value), 0.0, 1.0)
	# an outline that passes this close to the middle goes through it: no sliver of a wall
	if share < MIDDLE_SNAP:
		return MIDDLE
	return MIDDLE + (corner - MIDDLE) * share


func _world(i: int, j: int, uv: Vector2, y: float) -> Vector3:
	return Vector3(_x0 + float(i) + uv.x, y, _z0 + float(j) + uv.y)


func _top(
	i: int,
	j: int,
	bucket: MeshBucket,
	poly: Array[Vector2],
	nodes: PackedInt32Array,
	levels: PackedInt32Array,
	level: int
) -> void:
	var y := TerrainField.level_height(level)
	var first := _world(i, j, poly[0], y)
	var first_colour := _top_colour(nodes, levels, poly[0], level)
	for k in range(1, poly.size() - 1):
		if (poly[k] - poly[0]).cross(poly[k + 1] - poly[0]) == 0.0:
			continue
		bucket.tri(
			first,
			_world(i, j, poly[k], y),
			_world(i, j, poly[k + 1], y),
			Vector3.UP,
			first_colour,
			_top_colour(nodes, levels, poly[k], level),
			_top_colour(nodes, levels, poly[k + 1], level)
		)


## The grass at a point of a square on a level: its corners' colours blended, shaded by the
## terrace, and darkened (alpha) toward any corner on a higher level (the foot of a cliff).
func _top_colour(
	nodes: PackedInt32Array, levels: PackedInt32Array, uv: Vector2, level: int
) -> Color:
	if level == TerrainField.GORGE:
		return Color(TerrainPalette.GORGE_BED.srgb_to_linear(), 1.0)
	var w0 := (1.0 - uv.x) * (1.0 - uv.y)
	var w1 := uv.x * (1.0 - uv.y)
	var w2 := uv.x * uv.y
	var w3 := (1.0 - uv.x) * uv.y
	var colour := (
		_node_colour[nodes[0]] * w0
		+ _node_colour[nodes[1]] * w1
		+ _node_colour[nodes[2]] * w2
		+ _node_colour[nodes[3]] * w3
	)
	var higher := 0.0
	higher += w0 if levels[0] > level else 0.0
	higher += w1 if levels[1] > level else 0.0
	higher += w2 if levels[2] > level else 0.0
	higher += w3 if levels[3] > level else 0.0
	colour = _terrace_shade(colour, level)
	return Color(colour.srgb_to_linear(), 1.0 - FOOT_SHADE * higher)


## Higher terraces a little drier and lighter, the valley floor a little cooler.
static func _terrace_shade(colour: Color, level: int) -> Color:
	var shaded := colour.lerp(TerrainPalette.GRASS_DRY, clampf(0.02 * float(level), 0.0, 0.15))
	var light := 0.94 + 0.03 * float(mini(level, 6))
	return Color(shaded.r * light, shaded.g * light, shaded.b * light)


## A cliff from level `span.x` down to level `span.y`, along the outline between the first two
## of `ends` (points of the square), facing away from the third: stacked layers of corrugated
## kraft, one a terrace, each under a dark soil band (the top one under the grass edge), the card
## darkening toward the foot.
func _wall(
	i: int,
	j: int,
	bucket: MeshBucket,
	ends: Array[Vector2],
	nodes: PackedInt32Array,
	levels: PackedInt32Array,
	span: Vector2i,
	far: bool
) -> void:
	var a := ends[0]
	var b := ends[1]
	var along := b - a
	if along.length_squared() < 1e-10:
		return
	var out := Vector2(-along.y, along.x)
	if out.dot(ends[2] - a) < 0.0:
		out = -out
	var outward := Vector3(out.x, 0.0, out.y).normalized()
	var top := TerrainField.level_height(span.x)
	var points: Array[Vector3] = [_world(i, j, a, 0.0), _world(i, j, b, 0.0)]
	var ridges: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	if not far:
		ridges = [_ridge(points[0], a), _ridge(points[1], b)]
	var kraft: Array[Color] = []
	for point in points:
		var fibre := _field.noise(point.x * 3.0, point.z * 3.0, 1.0, SALT_KRAFT)
		kraft.append(TerrainPalette.KRAFT * (0.82 + 0.3 * fibre))
	var lip_grass := TerrainPalette.LIP_GRASS.srgb_to_linear()
	var grass_a := _top_colour(nodes, levels, a, span.x)
	var grass_b := _top_colour(nodes, levels, b, span.x)
	var soil := Color(TerrainPalette.SOIL.srgb_to_linear(), 0.85)
	var upper: Array[Vector3] = [
		points[0] + Vector3(0.0, top, 0.0), points[1] + Vector3(0.0, top, 0.0)
	]
	var upper_colours: Array[Color] = [
		Color(grass_a.lerp(lip_grass, 0.5), grass_a.a),
		Color(grass_b.lerp(lip_grass, 0.5), grass_b.a)
	]
	var level := span.x
	while level > span.y:
		# out in the haze a cliff is one face from top to foot
		var below := span.y if far else level - 1
		var layer_top := TerrainField.level_height(level)
		var foot_y := TerrainField.level_height(below) - (SINK if below == span.y else 0.0)
		var lips: Array[Vector3] = []
		var feet: Array[Vector3] = []
		var kraft_top: Array[Color] = []
		var kraft_foot: Array[Color] = []
		for k in 2:
			lips.append(points[k] + ridges[k] * LIP_RIDGE + Vector3(0.0, layer_top - LIP, 0.0))
			feet.append(points[k] + ridges[k] + Vector3(0.0, foot_y, 0.0))
			kraft_top.append(
				Color(_kraft(kraft[k], top - layer_top + LIP, below).srgb_to_linear(), 0.95)
			)
			var foot_shade := 1.0 - WALL_FOOT_SHADE if below == span.y else 0.9
			kraft_foot.append(
				Color(_kraft(kraft[k], top - foot_y, below).srgb_to_linear(), foot_shade)
			)
		if level == span.x and not far:
			# the top layer: the grass edge over the soil lip, then the card
			bucket.facet(
				upper[0], upper[1], lips[1], outward, upper_colours[0], upper_colours[1], soil
			)
			bucket.facet(upper[0], lips[1], lips[0], outward, upper_colours[0], soil, soil)
			bucket.facet(
				lips[0], lips[1], feet[1], outward, kraft_top[0], kraft_top[1], kraft_foot[1]
			)
			bucket.facet(
				lips[0], feet[1], feet[0], outward, kraft_top[0], kraft_foot[1], kraft_foot[0]
			)
		else:
			# a layer under it (or any layer far out in the haze): one face, dark at its seam
			var seam: Array[Color] = [soil, soil]
			if level == span.x:
				seam = upper_colours
			bucket.facet(upper[0], upper[1], feet[1], outward, seam[0], seam[1], kraft_foot[1])
			bucket.facet(upper[0], feet[1], feet[0], outward, seam[0], kraft_foot[1], kraft_foot[0])
		upper = feet
		level = below


## The kraft of a wall `drop` metres under its top: darker the deeper, and darkest in the gorge.
static func _kraft(lit: Color, drop: float, level: int) -> Color:
	var deep := clampf(drop / DEEP_WALL, 0.0, 1.0)
	if level < 0:
		deep = minf(1.0, deep + 0.15)
	return lit.lerp(TerrainPalette.KRAFT_DARK, 0.1 + 0.55 * deep)


## How far a wall corner at a point of the square leans out of line (x and z only). Corners on
## the square's edge, which the next square's walls share, never move, so no crack opens
## between squares; inside the square every wall that shares the corner moves it alike.
func _ridge(point: Vector3, uv: Vector2) -> Vector3:
	if uv.x <= 1e-4 or uv.y <= 1e-4 or uv.x >= 1.0 - 1e-4 or uv.y >= 1.0 - 1e-4:
		return Vector3.ZERO
	var rx := _field.noise(point.x, point.z, RIDGE_SPACING, SALT_RIDGE_X) - 0.5
	var rz := _field.noise(point.x, point.z, RIDGE_SPACING, SALT_RIDGE_Z) - 0.5
	return Vector3(rx, 0.0, rz) * (2.0 * RIDGE)
