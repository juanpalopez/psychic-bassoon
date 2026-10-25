extends GutTest
## No socket cell of the layout valley is a road cell (#517): the stitcher marks the road bed after
## the regions placed their sockets, so a socket the band reaches in the stitched map is a defect.

const SWEEP_FIRST := 1
const SWEEP_LAST := 300
const LATE_FIRST := 3001
const LATE_LAST := 3050


func _road_sockets(seed: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var map := MapGen.generate_layout_valley(seed)
	if map == null:
		return found
	for anchor in map.sockets:
		for dy in map.footprint:
			for dx in map.footprint:
				if map.tiles[anchor.y + dy][anchor.x + dx] == GameMap.Tile.ROAD:
					found.append(anchor + Vector2i(dx, dy))
	return found


func test_no_socket_cell_is_a_road_cell_on_the_first_seeds() -> void:
	for seed in range(SWEEP_FIRST, SWEEP_LAST + 1):
		assert_eq(_road_sockets(seed), [] as Array[Vector2i], "seed %d" % seed)


func test_no_socket_cell_is_a_road_cell_on_later_seeds() -> void:
	for seed in range(LATE_FIRST, LATE_LAST + 1):
		assert_eq(_road_sockets(seed), [] as Array[Vector2i], "seed %d" % seed)
