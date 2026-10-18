## The river's water: a flat sheet at `TerrainField.WATER_HEIGHT` over every gorge cell, run in
## under the banks so no gap shows at the foot of a cliff, with foam (vertex alpha) toward the
## banks. Chunked like the terraces. The water shader moves and colours it.
@tool
class_name WaterBuilder
extends DioramaBuilder

## How far the sheet runs in under a bank, in cells.
const UNDER_BANK := 0.45
## The foam starts this far from a cell's middle toward a bank and is full at the sheet's edge.
const FOAM_FROM := 0.5
## The pieces under the banks lie this much (or twice this) under the cell's own square.
const STRIP_DROP := 0.003

## The material the water wears (`Diorama` sets it).
var material: Material


func build(field: TerrainField) -> void:
	clear()
	var buckets := {}
	var y := TerrainField.WATER_HEIGHT
	for j in field.size.y:
		for i in field.size.x:
			var cell := field.origin + Vector2i(i, j)
			if not field.is_gorge(cell):
				continue
			var key := TerraceBuilder.chunk_of(i, j)
			if not buckets.has(key):
				buckets[key] = MeshBucket.new()
			_cell(field, cell, y, buckets[key])
	var keys := buckets.keys()
	keys.sort()
	for key in keys:
		var chunk: Vector2i = key
		add_mesh("Water_%d_%d" % [chunk.x, chunk.y], buckets[key].to_mesh(), material, false)


## The sheet over one gorge cell: its square, plus a strip under each bank beside it and a
## corner piece where two banks meet over a bank corner.
func _cell(field: TerrainField, cell: Vector2i, y: float, bucket: MeshBucket) -> void:
	var at := field.cell_centre(cell)
	var bank := {}
	for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		bank[side] = not field.is_gorge(cell + side)
	# the pieces as boxes of offsets from the cell's middle (x across, y in depth)
	var pieces: Array[Rect2] = [Rect2(-0.5, -0.5, 1.0, 1.0)]
	if bank[Vector2i.LEFT]:
		pieces.append(Rect2(-0.5 - UNDER_BANK, -0.5, UNDER_BANK, 1.0))
	if bank[Vector2i.RIGHT]:
		pieces.append(Rect2(0.5, -0.5, UNDER_BANK, 1.0))
	if bank[Vector2i.UP]:
		pieces.append(Rect2(-0.5, -0.5 - UNDER_BANK, 1.0, UNDER_BANK))
	if bank[Vector2i.DOWN]:
		pieces.append(Rect2(-0.5, 0.5, 1.0, UNDER_BANK))
	for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var across := Vector2i(corner.x, 0)
		var deep := Vector2i(0, corner.y)
		# where two banks meet, under the corner of the land (the diagonal cell may be gorge too:
		# its own square lies higher than this piece, so the two never fight)
		if bank[across] and bank[deep]:
			var x := -0.5 - UNDER_BANK if corner.x < 0 else 0.5
			var z := -0.5 - UNDER_BANK if corner.y < 0 else 0.5
			pieces.append(Rect2(x, z, UNDER_BANK, UNDER_BANK))
	for k in pieces.size():
		var piece := pieces[k]
		# the pieces under the banks of two cells side-stepping the river can overlap: they lie a
		# hair under the cell's square, at a height by column so neighbours never share a plane
		var lift := 0.0 if k == 0 else -STRIP_DROP * float(1 + posmod(cell.x, 2))
		if k > 0 and piece.size.x < 1.0 and piece.size.y < 1.0:
			lift -= 2.0 * STRIP_DROP
		var points: Array[Vector2] = [
			piece.position,
			Vector2(piece.end.x, piece.position.y),
			piece.end,
			Vector2(piece.position.x, piece.end.y),
		]
		var corners: Array[Vector3] = []
		var colours: Array[Color] = []
		for point in points:
			corners.append(Vector3(at.x + point.x, y + lift, at.z + point.y))
			colours.append(Color(1.0, 1.0, 1.0, _foam(point, bank)))
		bucket.quad(
			corners[0],
			corners[1],
			corners[2],
			corners[3],
			Vector3.UP,
			colours[0],
			colours[1],
			colours[2],
			colours[3]
		)


## The foam at an offset from the cell's middle: rising toward each bank beside the cell.
func _foam(point: Vector2, bank: Dictionary) -> float:
	var foam := 0.0
	var reach := 0.5 + UNDER_BANK - FOAM_FROM
	if bank[Vector2i.LEFT]:
		foam = maxf(foam, (-point.x - FOAM_FROM) / reach)
	if bank[Vector2i.RIGHT]:
		foam = maxf(foam, (point.x - FOAM_FROM) / reach)
	if bank[Vector2i.UP]:
		foam = maxf(foam, (-point.y - FOAM_FROM) / reach)
	if bank[Vector2i.DOWN]:
		foam = maxf(foam, (point.y - FOAM_FROM) / reach)
	return clampf(foam, 0.0, 1.0)
