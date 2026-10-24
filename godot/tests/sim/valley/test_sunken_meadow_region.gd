extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 300
const STITCH_STEP := 6
const ID := ValleyLayout.Region.SUNKEN_MEADOW

var _layouts := {}


func _layout(seed: int) -> ValleyLayout:
	if not _layouts.has(seed):
		_layouts[seed] = ValleyLayout.generate(seed, 40, 24)
	return _layouts[seed]


func _drawn(seed: int) -> Array:
	var layout := _layout(seed)
	var section := SunkenMeadowRegion.new()
	var result := section.generate(layout.slots[ID], layout.rng_for(ID, 0))
	return [layout, section, result]


func test_four_or_five_low_blocks_that_pass_the_checks() -> void:
	var failed := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		assert_between(result.sockets.size(), 4, 5, "seed %d" % seed)
		assert_eq(result.socket_levels.count(0), result.sockets.size())
		if not ValleyChecks.section_problems(drawn[0].slots[ID], result, drawn[1]).is_empty():
			failed += 1
	assert_lte(failed, SWEEP / 10, "%d of %d first attempts failed" % [failed, SWEEP])


func test_open_ground_with_no_cliffs_and_flat_heights() -> void:
	for seed in range(1, SWEEP + 1, 3):
		var result: SectionResult = _drawn(seed)[2]
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				assert_eq(result.height_at(cell), 0)
				assert_true(
					(
						result.region_at(cell) in [GameMap.Region.MEADOW, GameMap.Region.DIRT]
						or (
							result.region_at(cell) == GameMap.Region.ROCKS
							and not result.is_walkable(cell)
						)
					)
				)


func test_boulders_never_cut_the_walkable_ground() -> void:
	var boulders := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				if result.region_at(Vector2i(x, y)) == GameMap.Region.ROCKS:
					boulders += 1
		assert_true(_one_piece(drawn[0].slots[ID], result), "seed %d" % seed)
	assert_gt(boulders, 0)


func test_the_road_is_the_spline_of_the_spine() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		assert_eq(result.road, RoadSpline.build(drawn[0].slots[ID].spine).cells)
		assert_not_null(result.road_curve)


func test_every_seed_stitches_a_valley_with_no_problems() -> void:
	for seed in range(1, SWEEP + 1, STITCH_STEP):
		var layout := _layout(seed)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		assert_not_null(map, "seed %d stitches" % seed)


func test_the_same_seed_draws_the_same_meadow() -> void:
	for seed in SEEDS:
		var a: SectionResult = _drawn(seed)[2]
		var b: SectionResult = _drawn(seed)[2]
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.heights, b.heights)
		assert_eq(a.walkable, b.walkable)


## True when every walkable cell of the region joins the entry.
func _one_piece(slot: ValleyPlan.Slot, result: SectionResult) -> bool:
	var walkable := 0
	for y in range(slot.rect.position.y, slot.rect.end.y):
		for x in range(slot.rect.position.x, slot.rect.end.x):
			walkable += 1 if result.is_walkable(Vector2i(x, y)) else 0
	var seen := {slot.entry: true}
	var queue: Array[Vector2i] = [slot.entry]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if slot.rect.has_point(next) and not seen.has(next) and result.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == walkable and walkable >= 70
