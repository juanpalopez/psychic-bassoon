## Writes a map's terrain layer as plain JSON data for the terrain golden
## (`tests/goldens/terrain.json`, written by `tools/write_terrain_golden.gd`).
class_name TerrainKit
extends RefCounted

## The valley seeds the golden pins: a few spread-out seeds and the edges of the seed range.
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]


## One seed's layer: each row of heights and of regions as a string of digits, the river as
## `[x, y]` pairs and each bridge as `[x, y, horizontal, path_index]`.
static func encode(map: GameMap) -> Dictionary:
	var heights := []
	var regions := []
	for y in map.rows:
		var height_row := ""
		var region_row := ""
		for x in map.cols:
			height_row += str(map.height_at(Vector2i(x, y)))
			region_row += str(map.region_at(Vector2i(x, y)))
		heights.append(height_row)
		regions.append(region_row)
	var river := []
	for cell in map.river:
		river.append([cell.x, cell.y])
	var bridges := []
	for bridge in map.bridges:
		bridges.append([bridge.cell.x, bridge.cell.y, bridge.horizontal, bridge.path_index])
	return {
		"seed": map.seed,
		"heights": heights,
		"regions": regions,
		"river": river,
		"bridges": bridges,
	}


## The layers for every seed in `SEEDS`, on the route-first generator's 32 by 20 board (the
## terrain layer the golden pins; the game board is the sectioned valley).
static func record() -> Array:
	var out := []
	for map_seed in SEEDS:
		out.append(encode(MapGen.generate(map_seed)))
	return out
