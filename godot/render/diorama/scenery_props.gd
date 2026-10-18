## The scenery's props, generated as faceted papercraft (docs/art/STYLE.md: "faceted cone pines
## and round broadleaf trees, grey-brown boulders split into facets, dirt patches and grass
## tufts"): flat-shaded facets with their colours (`TerrainPalette`, linear) in the vertex
## colours, in the painted paper the ground wears (`painted.gdshader`), each prop one surface.
## A prop stands on its origin, one cell is one unit, and it is built to
## `DioramaLooks.PROP_RADIUS`; its footprint at scale 1 is measured on the meshes (`reach`).
## `light` gives the plainer mesh the scenery past the board's margin wears (fewer facets, no
## trunk). Every mesh is made once and shared; nothing here is random: the facets' jitter comes
## from `CellHash` on fixed keys, so the props look the same every run. Scripted with Claude in
## code, they count as the owner's own models (CLAUDE.md).
class_name SceneryProps
extends RefCounted

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const KINDS: Array[String] = ["pine", "broadleaf", "shrub", "boulder", "dirt", "grass"]
## The props flat on the ground, which cast no shadow (a blade of grass carries both its faces).
const GROUND_COVER: Array[String] = ["dirt", "grass"]

static var _meshes := {}


## The shared mesh of a prop kind (one of `KINDS`), plain when `light`.
static func mesh(kind: String, light: bool) -> ArrayMesh:
	var key := "%s %s" % [kind, light]
	if _meshes.has(key):
		return _meshes[key]
	var facets := FacetMesh.new()
	match kind:
		"pine":
			_pine(facets, light)
		"broadleaf":
			_broadleaf(facets, light)
		"shrub":
			_shrub(facets)
		"boulder":
			_boulder(facets, light)
		"dirt":
			_dirt(facets)
		"grass":
			_grass(facets)
		_:
			push_error("no scenery prop called %s" % kind)
	var made := facets.commit(PaperLook.material("painted"))
	_meshes[key] = made
	return made


## How far a prop reaches from its foot on the ground at scale 1 (cells): the furthest any vertex
## of either of its meshes lies from the vertical axis. A placement's footprint is this times its
## size.
static func reach(kind: String) -> float:
	var key := "reach %s" % kind
	if _meshes.has(key):
		return _meshes[key]
	var furthest := 0.0
	for light: bool in [false, true]:
		for v: Vector3 in mesh(kind, light).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			furthest = maxf(furthest, Vector2(v.x, v.z).length())
	_meshes[key] = furthest
	return furthest


## How many triangles a prop's mesh has.
static func triangles(kind: String, light: bool) -> int:
	return mesh(kind, light).surface_get_array_len(0) / 3


## A cone pine: tiers of folded card, each turned half a facet from the one below and lighter
## higher up, on a short trunk. The light pine has the same outline (as tall, as wide at the foot,
## the same colours) in two tiers, so the switch at a chunk's edge does not jump.
static func _pine(facets: FacetMesh, light: bool) -> void:
	var reach: float = LOOKS.PROP_RADIUS["pine"]
	# each tier: its foot's height, its radius (a share of the reach) and its tip's height
	var tiers: Array[Vector3] = [
		Vector3(0.16, 1.0, 0.71), Vector3(0.477, 0.75, 0.947), Vector3(0.793, 0.5, 1.183)
	]
	if light:
		tiers = [Vector3(0.08, 1.0, 0.8), Vector3(0.5, 0.65, 1.183)]
	else:
		_trunk(facets, 0.045, 0.21)
	for tier in tiers.size():
		var shape := tiers[tier]
		var share := float(tier) / float(tiers.size() - 1)
		var apex := Vector3(0.0, shape.z, 0.0)
		var ring := _ring(5, reach * shape.y, shape.x, 0.5 * float(tier), 0)
		var inside := Vector3(0.0, shape.x + 0.1, 0.0)
		for k in 5:
			var tone := TerrainPalette.PINE_SHADE.lerp(TerrainPalette.PINE, 0.3 + 0.7 * share)
			tone = tone.lightened(0.05 * (_facet(k, tier, 3) + 1.0))
			facets.triangle(apex, ring[k], ring[(k + 1) % 5], tone, inside)


## A round broadleaf: a lumpy faceted crown (an icosahedron pulled about), lighter on top, on a
## trunk.
static func _broadleaf(facets: FacetMesh, light: bool) -> void:
	var reach: float = LOOKS.PROP_RADIUS["broadleaf"]
	var middle := Vector3(0.0, 0.6, 0.0)
	if light:
		# a five-sided cone of a crown, seen from above, far off
		var ring := _ring(5, reach, middle.y - reach * 0.4, 0.0, 3)
		var top := middle + Vector3(0.0, reach * 0.8, 0.0)
		for k in 5:
			facets.triangle(
				top, ring[k], ring[(k + 1) % 5], _crown_tone(0.7 + 0.1 * float(k % 3), k), middle
			)
		return
	_trunk(facets, 0.05, 0.36)
	var t := (1.0 + sqrt(5.0)) / 2.0
	var corners: Array[Vector3] = [
		Vector3(-1, t, 0),
		Vector3(1, t, 0),
		Vector3(-1, -t, 0),
		Vector3(1, -t, 0),
		Vector3(0, -1, t),
		Vector3(0, 1, t),
		Vector3(0, -1, -t),
		Vector3(0, 1, -t),
		Vector3(t, 0, -1),
		Vector3(t, 0, 1),
		Vector3(-t, 0, -1),
		Vector3(-t, 0, 1),
	]
	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1),
	]
	var size := reach / sqrt(1.0 + t * t)
	var points: Array[Vector3] = []
	for i in corners.size():
		var lump := 0.85 + 0.3 * CellHash.of(i, 3, 7, 41)
		var point := corners[i] * size * lump
		points.append(middle + Vector3(point.x, point.y * 0.85, point.z))
	for f in faces.size():
		var face := faces[f]
		var a := points[face.x]
		var b := points[face.y]
		var c := points[face.z]
		var up := clampf(((a + b + c) / 3.0 - middle).normalized().y * 0.5 + 0.5, 0.0, 1.0)
		facets.triangle(a, b, c, _crown_tone(up, f), middle)


static func _crown_tone(up: float, facet: int) -> Color:
	var tone := TerrainPalette.BROADLEAF_SHADE.lerp(TerrainPalette.BROADLEAF, 0.25 + 0.75 * up)
	return tone.lightened(0.05 * _facet(facet, 2, 2))


## A low five-sided dome of a bush, its skirt folded down between the facets of its top.
static func _shrub(facets: FacetMesh) -> void:
	var reach: float = LOOKS.PROP_RADIUS["shrub"]
	var foot := _ring(5, reach * 0.8, -0.02, 0.5, 4)
	var waist := _ring(5, reach, 0.1, 0.0, 5)
	var top := Vector3(0.0, 0.26, 0.0)
	var inside := Vector3(0.0, 0.08, 0.0)
	for k in 5:
		var j := (k + 1) % 5
		var lit := TerrainPalette.SHRUB.lightened(0.06 * _facet(k, 5, 3))
		facets.triangle(top, waist[k], waist[j], lit, inside)
		var side := TerrainPalette.SHRUB.darkened(0.18 + 0.05 * _facet(k, 6, 3))
		facets.triangle(waist[k], foot[k], waist[j], side, inside)


## A boulder split into facets: a jittered ring round a top point, sloping to a wider foot sunk a
## little into the ground (after the look-dev `rock`).
static func _boulder(facets: FacetMesh, light: bool) -> void:
	var reach: float = LOOKS.PROP_RADIUS["boulder"]
	var sides := 4 if light else 6
	var inside := Vector3(0.0, 0.08, 0.0)
	var top := Vector3(0.03, reach * 1.05, -0.02)
	var ring: Array[Vector3] = []
	var foot: Array[Vector3] = []
	for k in sides:
		var angle := TAU * float(k) / float(sides)
		var out := reach * (0.7 + 0.3 * CellHash.of(k, sides, 11, 43))
		var high := reach * (0.35 + 0.3 * CellHash.of(k, sides, 12, 43))
		ring.append(Vector3(cos(angle) * out, high, sin(angle) * out))
		var low := angle + PI / float(sides)
		var wide := reach * (0.9 + 0.12 * CellHash.of(k, sides, 13, 43))
		foot.append(Vector3(cos(low) * wide, -0.04, sin(low) * wide))
	var stone: Color = TerrainPalette.STONES[0]
	for k in sides:
		var j := (k + 1) % sides
		facets.triangle(
			top, ring[k], ring[j], stone.lightened(0.08 + 0.05 * _facet(k, 7, 3)), inside
		)
		facets.triangle(
			ring[k], foot[k], ring[j], stone.darkened(0.08 + 0.05 * _facet(k, 8, 3)), inside
		)
		var prev := (k + sides - 1) % sides
		facets.triangle(ring[k], foot[prev], foot[k], stone.darkened(0.16), inside)


## A patch of bare earth lying on the grass: a ragged seven-sided fan, darker in the middle and
## fading to the dry grass colour at its edge.
static func _dirt(facets: FacetMesh) -> void:
	var reach: float = LOOKS.PROP_RADIUS["dirt"]
	var middle := Vector3(0.0, 0.006, 0.0)
	var below := Vector3(0.0, -1.0, 0.0)
	var edge: Array[Vector3] = []
	for k in 7:
		var angle := TAU * float(k) / 7.0
		var out := reach * (0.7 + 0.3 * CellHash.of(k, 7, 21, 49))
		edge.append(Vector3(cos(angle) * out, 0.004, sin(angle) * out))
	var rim := TerrainPalette.DIRT_PATCH.lerp(TerrainPalette.DIRT_PATCH_EDGE, 0.7)
	for k in 7:
		facets.shaded_triangle(
			[middle, edge[k], edge[(k + 1) % 7]], [TerrainPalette.DIRT_PATCH, rim, rim], below
		)


## A tuft of three blades, each drawn on both faces, green at the root and dry at the tip.
static func _grass(facets: FacetMesh) -> void:
	for blade in 3:
		var angle := TAU * float(blade) / 3.0 + 0.4
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var across := Vector3(-out.z, 0.0, out.x) * 0.045
		var root := out * 0.03
		var tip := out * 0.1 + Vector3(0.0, 0.22 + 0.04 * float(blade), 0.0)
		var corners: Array[Vector3] = [root - across, root + across, tip]
		var colours: Array[Color] = [
			TerrainPalette.GRASS_BLADE, TerrainPalette.GRASS_BLADE, TerrainPalette.GRASS_TIP
		]
		var side := across.cross(Vector3.UP).normalized() * 0.05
		facets.shaded_triangle(corners, colours, root + side)
		facets.shaded_triangle(corners, colours, root - side)


## A three-sided trunk from the ground up to `height`.
static func _trunk(facets: FacetMesh, half: float, height: float) -> void:
	var foot := _ring(3, half, -0.02, 0.25, 0)
	var top := _ring(3, half * 0.8, height, 0.25, 0)
	var inside := Vector3(0.0, height / 2.0, 0.0)
	for k in 3:
		var j := (k + 1) % 3
		var tone := TerrainPalette.TRUNK.darkened(0.08 * float(k))
		facets.quad(foot[k], foot[j], top[j], top[k], tone, inside)


## `sides` points round the vertical axis at `height`, `radius` out, turned by `turn` of a facet,
## each pushed in or out a little (a fixed jitter keyed on `key`).
static func _ring(
	sides: int, radius: float, height: float, turn: float, key: int
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for k in sides:
		var angle := TAU * (float(k) + turn) / float(sides)
		var out := radius * (0.9 + 0.2 * CellHash.of(k, key, sides, 47))
		points.append(Vector3(cos(angle) * out, height, sin(angle) * out))
	return points


## A facet's fixed tone step, from -1 to 1, so neighbouring facets differ.
static func _facet(k: int, salt: int, steps: int) -> float:
	return float((k * 7 + salt * 3) % steps) / float(maxi(steps - 1, 1)) * 2.0 - 1.0
