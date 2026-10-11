## What a tower's panel and ring say, from the content (not a second copy).
extends GutTest


func _tower(type: String, level: int, invested: int = 0) -> Tower:
	var tower := Tower.new()
	tower.type = type
	tower.level = level
	tower.invested = invested
	return tower


func test_the_range_is_the_levels_base_range() -> void:
	var map := MapGen.generate(1)
	var level_0_socket := Vector2i(-1, -1)
	for cell in map.sockets:
		if map.elevation_at(cell) == 0:
			level_0_socket = cell
			break
	var tower := _tower("ballista", 0)
	tower.col = level_0_socket.x
	tower.row = level_0_socket.y
	assert_almost_eq(TowerInfo.effective_range(map, tower), 2.3, 1e-9)
	tower.level = 2
	assert_almost_eq(TowerInfo.effective_range(map, tower), 3.0, 1e-9)


func test_a_level_2_socket_reaches_15_percent_further() -> void:
	var found := false
	for map_seed in range(1, 60):
		var map := MapGen.generate(map_seed)
		for cell in map.sockets:
			if map.elevation_at(cell) == 2:
				var tower := _tower("catapult", 1)
				tower.col = cell.x
				tower.row = cell.y
				# a level 2 Catapult reaches 3.1 cells, times 1.15
				assert_almost_eq(TowerInfo.effective_range(map, tower), 3.1 * 1.15, 1e-9)
				found = true
				break
		if found:
			break
	assert_true(found, "a level 2 socket exists")


func test_the_next_upgrade_cost_and_none_at_the_top() -> void:
	assert_eq(TowerInfo.next_cost(_tower("ballista", 0)), 60)
	assert_eq(TowerInfo.next_cost(_tower("ballista", 1)), 110)
	assert_eq(TowerInfo.next_cost(_tower("ballista", 2)), -1)


func test_the_refund_is_70_percent_of_what_was_spent_rounded_down() -> void:
	assert_eq(TowerInfo.refund(_tower("ballista", 0, 50)), 35)
	# 90 * 0.7 is 62.99999999999999 in 64-bit floats, so 62, like the sim
	assert_eq(TowerInfo.refund(_tower("catapult", 0, 90)), 62)
	assert_eq(TowerInfo.refund(_tower("ballista", 1, 110)), 77)
