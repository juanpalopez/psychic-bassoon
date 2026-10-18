## A placeholder road bed until #325's `RoadBedBuilder` lays the real ones (packed earth and
## flagstones along the routes, and the bridges): a sand ribbon with a worn edge along the line
## each road's foes walk (`TerrainField.routes`), carried on past the map along the field's leads,
## and a plank deck where it crosses the river. Every road cell is under it. One mesh, one
## draw call.
@tool
class_name PlaceholderRoadBed
extends DioramaBuilder

## Half the ribbon's width, and the worn edge's share of it.
const HALF_WIDTH := 0.44
const EDGE_SHARE := 0.22
## The bed lies under where the foes walk (`TerrainField.ROAD_HEIGHT`); each later road a hair
## lower, so a feeder never fights the main road where it joins.
const BED_HEIGHT := 0.006
const ROAD_STEP := 0.0015
const SALT_SAND := 731
## A straight stretch keeps every this-many-th point, so the sand's colour still varies along it.
const THIN_EVERY := 6
## A later road has joined one laid before once its line comes this close to that road's.
const JOINED := 0.02

## The material the bed wears (`Diorama` sets it).
var material: Material


func build(field: TerrainField) -> void:
	clear()
	var bucket := MeshBucket.new()
	var drawn := {}
	var laid: Array[Vector2] = []
	var bridges := {}
	for bridge in field.map.bridges:
		bridges[bridge.cell] = true
	for r in field.map.routes.size():
		var cells: Array = field.map.routes[r]
		var points: Array[Vector2] = []
		var lead := _lead_for(field, cells[0])
		for k in range(lead.size() - 1, -1, -1):
			var at := field.cell_centre(lead[k])
			points.append(Vector2(at.x, at.z))
		# the line the foes walk (curved through the corners on the valley board), from the
		# spawn point off the edge; a later road stops where it joins one already laid
		var route: Route = field.routes[r]
		for p in route.xs.size():
			var at := BoardSpace.point_to_world(route.xs[p], route.ys[p])
			points.append(Vector2(at.x, at.z))
			# past the join cell, once its curve has met the road laid before
			if p > 0 and drawn.has(field.cell_under(at)) and _on_line(at, laid):
				break
		for p in route.xs.size():
			var at := BoardSpace.point_to_world(route.xs[p], route.ys[p])
			laid.append(Vector2(at.x, at.z))
		for cell in cells:
			drawn[cell] = true
		_ribbon(field, bucket, points, BED_HEIGHT - ROAD_STEP * float(r), bridges)
	add_mesh("RoadBed", bucket.to_mesh(), material, false)


## Whether `at` lies on a road already laid (within `JOINED` of one of its points).
static func _on_line(at: Vector3, laid: Array[Vector2]) -> bool:
	for point in laid:
		if point.distance_to(Vector2(at.x, at.z)) < JOINED:
			return true
	return false


## The cells a road carries on through past the map from its start, if it leaves at an edge.
func _lead_for(field: TerrainField, start: Vector2i) -> Array[Vector2i]:
	for lead in field.leads:
		var cells: Array[Vector2i] = lead
		if not cells.is_empty() and (cells[0] - start).abs().x + (cells[0] - start).abs().y == 1:
			return cells
	return [] as Array[Vector2i]


func _ribbon(
	field: TerrainField, bucket: MeshBucket, points: Array[Vector2], y: float, bridges: Dictionary
) -> void:
	if points.size() < 2:
		return
	points = _thinned(field, points, bridges)
	var previous: Array[Vector3] = []
	var previous_colours: Array[Color] = []
	for k in points.size():
		var ahead := points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]
		var side := Vector2(-ahead.y, ahead.x).normalized()
		var point := points[k]
		var on_bridge := bridges.has(field.cell_under(Vector3(point.x, 0.0, point.y)))
		var half := HALF_WIDTH * (1.15 if on_bridge else 1.0)
		var across: Array[Vector3] = []
		for share in [-1.0, -(1.0 - EDGE_SHARE), 1.0 - EDGE_SHARE, 1.0]:
			var at: Vector2 = point + side * half * float(share)
			across.append(Vector3(at.x, y, at.y))
		var colours := _colours(field, point, k, on_bridge)
		if not previous.is_empty():
			for s in 3:
				bucket.quad(
					previous[s],
					previous[s + 1],
					across[s + 1],
					across[s],
					Vector3.UP,
					previous_colours[s],
					previous_colours[s + 1],
					colours[s + 1],
					colours[s]
				)
		previous = across
		previous_colours = colours


## The colours across the ribbon at a point: worn edge, sand, sand, worn edge; planks on a bridge.
func _colours(field: TerrainField, point: Vector2, k: int, on_bridge: bool) -> Array[Color]:
	if on_bridge:
		var plank := TerrainPalette.PLANK if k % 2 == 0 else TerrainPalette.PLANK_DARK
		var lit := Color(plank.srgb_to_linear(), 1.0)
		return [lit, lit, lit, lit]
	var grain := field.noise(point.x * 2.0, point.y * 2.0, 1.0, SALT_SAND)
	var sand := TerrainPalette.ROAD.lerp(TerrainPalette.ROAD_EDGE, 0.35 * grain)
	var edge := Color(TerrainPalette.ROAD_EDGE.srgb_to_linear(), 0.8)
	var middle := Color(sand.srgb_to_linear(), 1.0)
	return [edge, middle, middle, edge]


## The points that bend the ribbon, its ends, and those on a bridge (for the planks): a point in
## the middle of a straight stretch adds triangles and nothing else.
static func _thinned(
	field: TerrainField, points: Array[Vector2], bridges: Dictionary
) -> Array[Vector2]:
	var kept: Array[Vector2] = [points[0]]
	for k in range(1, points.size() - 1):
		var before := (points[k] - kept[kept.size() - 1]).normalized()
		var after := (points[k + 1] - points[k]).normalized()
		var at := field.cell_under(Vector3(points[k].x, 0.0, points[k].y))
		if before.dot(after) < 0.9999 or bridges.has(at) or k % THIN_EVERY == 0:
			kept.append(points[k])
	kept.append(points[points.size() - 1])
	return kept
