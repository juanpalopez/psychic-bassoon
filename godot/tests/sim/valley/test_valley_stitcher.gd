extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]


## A section that fails its checks on its first attempt (a road that jumps) and passes after.
class Flaky:
	extends StraightSection
	var calls := 0
	var failures := 1

	func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
		calls += 1
		var result := super(slot, rng)
		if calls <= failures:
			result.road.remove_at(1)
		return result


func test_the_valley_runs_from_the_left_edge_to_the_heartstone_in_unit_steps() -> void:
	for seed in SEEDS:
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		assert_eq(map.path[0].x, 0)
		assert_eq(map.path[map.path.size() - 1].x, 31)
		for index in map.path.size() - 1:
			assert_eq((map.path[index + 1] - map.path[index]).length_squared(), 1)
		assert_true(map.heartstone.has_point(map.path[map.path.size() - 1]))


func test_tiles_sockets_and_layers_match_the_board() -> void:
	for seed in SEEDS:
		var map := MapGen.generate_valley(seed)
		assert_eq(map.cols, 32)
		assert_eq(map.rows, 20)
		assert_eq(map.footprint, 2)
		for cell in map.path:
			assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD)
		for index in map.sockets.size():
			var anchor := map.sockets[index]
			assert_eq(map.socket_anchor_at(anchor + Vector2i(1, 1)), anchor)
			assert_eq(map.tiles[anchor.y][anchor.x], GameMap.Tile.PLOT)
			if index > 0:
				var before := map.sockets[index - 1]
				assert_true(before.y < anchor.y or (before.y == anchor.y and before.x < anchor.x))
		assert_eq(map.heights.size(), 20)
		assert_eq(map.regions[0].size(), 32)
		assert_true(map.is_walkable(Vector2i(0, map.path[0].y)))


func test_the_curved_route_builds_from_the_stitched_road() -> void:
	var map := MapGen.generate_valley(42)
	var route := Route.build_curved(map.path)
	assert_gt(route.cell_distance(map.path.size() - 1), float(map.path.size() - 1) * 0.8)


func test_the_same_seed_gives_the_same_valley() -> void:
	var first := MapGen.generate_valley(2026)
	var second := MapGen.generate_valley(2026)
	assert_eq(first.path, second.path)
	assert_eq(first.sockets, second.sockets)
	assert_eq(first.heights, second.heights)


func test_a_failing_section_is_drawn_again_and_the_others_do_not_change() -> void:
	var sections := ValleySections.all()
	var baseline := ValleyStitcher.build(42, 32, 20, sections)
	var flaky := Flaky.new()
	sections[3] = flaky
	var map := ValleyStitcher.build(42, 32, 20, sections)
	assert_not_null(map)
	assert_eq(flaky.calls, 2)
	var strip := ValleyPlan.create(42, 32, 20).slots[3].rect
	assert_eq(map.path, baseline.path)
	for anchor in baseline.sockets:
		if not strip.has_point(anchor):
			assert_true(map.sockets.has(anchor), "socket %s moved" % anchor)
	for y in 20:
		for x in 32:
			if not strip.has_point(Vector2i(x, y)):
				assert_eq(map.heights[y][x], baseline.heights[y][x])
				assert_eq(map.regions[y][x], baseline.regions[y][x])
				assert_eq(map.walkable[y][x], baseline.walkable[y][x])
				assert_eq(map.elevation[y][x], baseline.elevation[y][x])


func test_a_section_that_never_passes_gives_up_with_an_error() -> void:
	var sections := ValleySections.all()
	var flaky := Flaky.new()
	flaky.failures = 1000
	sections[1] = flaky
	var map := ValleyStitcher.build(42, 32, 20, sections)
	assert_null(map)
	assert_eq(flaky.calls, 20)
	assert_push_error("section 1 fails")


func test_every_seed_of_a_sweep_gives_a_valley() -> void:
	for seed in range(1, 201):
		assert_not_null(MapGen.generate_valley(seed), "seed %d" % seed)
