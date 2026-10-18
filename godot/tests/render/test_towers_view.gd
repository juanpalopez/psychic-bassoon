## The towers in the game state, one view each.
extends GutTest


func _tower(id: int, type: String, col: int, row: int, level: int = 0) -> Tower:
	var tower := Tower.new()
	tower.id = id
	tower.type = type
	tower.col = col
	tower.row = row
	tower.level = level
	return tower


func test_one_tower_scene_per_tower_at_its_cell() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.sync([_tower(0, "spoolGuard", 1, 2), _tower(1, "thimbleMortar", 3, 4)] as Array[Tower])
	assert_eq(view.get_child_count(), 2)
	var first := view.get_child(0) as TowerView
	assert_not_null(first)
	var at := BoardSpace.cell_to_world(1, 2)
	assert_almost_eq(first.position.x, at.x, 1e-6)
	assert_almost_eq(first.position.z, at.z, 1e-6)


func test_no_towers_means_no_scenes() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.sync([_tower(0, "spoolGuard", 1, 2)] as Array[Tower])
	view.sync([] as Array[Tower])
	assert_eq(view.get_child_count(), 0)


func test_a_higher_level_makes_a_taller_tower() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.sync([_tower(0, "spoolGuard", 1, 2, 0)] as Array[Tower])
	var low := (view.get_child(0) as TowerView).body_height()
	view.sync([_tower(0, "spoolGuard", 1, 2, 2)] as Array[Tower])
	var high := (view.get_child(0) as TowerView).body_height()
	assert_gt(high, low)


func test_syncing_the_same_towers_again_keeps_the_same_nodes() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	var towers: Array[Tower] = [_tower(0, "spoolGuard", 1, 2)]
	view.sync(towers)
	var node := view.get_child(0)
	view.sync(towers)
	assert_eq(view.get_child(0), node)


func test_a_tower_stands_on_the_surface_it_is_given() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	var surface := func(_cell: Vector2i) -> float: return 1.5
	view.sync([_tower(0, "spoolGuard", 1, 2, 0)] as Array[Tower], surface)
	assert_almost_eq((view.get_child(0) as TowerView).position.y, 1.5, 1e-6)


func test_towers_on_blocks_stand_at_the_blocks_centre() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.sync([_tower(0, "spoolGuard", 4, 2)] as Array[Tower], Callable(), 2)
	var middle := BoardSpace.footprint_centre(Vector2i(4, 2), 2)
	var node := view.get_child(0) as TowerView
	assert_almost_eq(node.position.x, middle.x, 1e-6)
	assert_almost_eq(node.position.z, middle.z, 1e-6)


func test_adding_or_selling_a_tower_keeps_the_other_towers_views() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	var first := _tower(0, "spoolGuard", 1, 2)
	view.sync([first] as Array[Tower])
	var kept := view.view_of(0)
	view.sync([first, _tower(1, "prismSpire", 5, 2)] as Array[Tower])
	assert_eq(view.view_of(0), kept, "a build leaves the other tower alone")
	view.sync([first] as Array[Tower])
	assert_eq(view.view_of(0), kept, "a sale leaves the other tower alone")
	assert_null(view.view_of(1), "the sold tower's view is gone")


func test_a_clip_asked_for_before_the_view_exists_plays_when_it_is_made() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.act(3, "deploy")
	view.sync([_tower(3, "guardTent", 1, 2)] as Array[Tower])
	assert_eq(view.view_of(3).clip(), "deploy")


func test_a_clip_for_a_tower_that_never_comes_is_dropped() -> void:
	var view := TowersView.new()
	add_child_autofree(view)
	view.act(9, "deploy")
	view.sync([] as Array[Tower])
	view.sync([_tower(9, "guardTent", 1, 2)] as Array[Tower])
	assert_eq(view.view_of(9).clip(), "idle", "the old request was dropped with the sync")
