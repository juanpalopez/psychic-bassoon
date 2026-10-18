## Beams that last as long as their lock, and where shots and beams leave a tower and
## land on a foe.
extends GutTest

const TOWER_SCENE := preload("res://render/tower_view.tscn")


func _view() -> ShotsView:
	var view := ShotsView.new()
	add_child_autofree(view)
	return view


func _beam_game() -> Array:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	return [scene, foe]


func test_a_locked_beam_draws_a_line_from_its_tower_to_its_foe() -> void:
	var made := _beam_game()
	var scene: TowerFireKit.Scene = made[0]
	var foe: Foe = made[1]
	assert_eq(scene.tower.target_id, foe.id)
	var view := _view()
	view.show_beams(scene.game, func(_cell: Vector2i) -> float: return 0.3)
	assert_eq(view.visible_beams(), 1)
	assert_eq(view.beam_to(0), ShotsView.body_point(foe.x, foe.y))
	assert_eq(view.beam_from(0), ShotsView.muzzle(scene.tower, 0.3, scene.game.map.footprint))


func test_a_beam_goes_when_its_lock_goes() -> void:
	var made := _beam_game()
	var scene: TowerFireKit.Scene = made[0]
	var view := _view()
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 1)
	assert_true(view.beam_line(0).visible)
	assert_true(view.beam_glow(0).visible, "a glow where it hits")
	assert_true(view.beam_line(0).material_override is ShaderMaterial, "the prism beam shader")
	scene.tower.target_id = -1
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 0)
	assert_false(view.beam_line(0).visible, "the line is hidden, not just uncounted")
	assert_false(view.beam_glow(0).visible)


func test_a_lock_on_a_fallen_foe_draws_no_beam() -> void:
	var made := _beam_game()
	var scene: TowerFireKit.Scene = made[0]
	var foe: Foe = made[1]
	foe.alive = false
	var view := _view()
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 0)


func test_a_tower_that_is_not_a_beam_draws_no_beam() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	var view := _view()
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 0)


func test_the_muzzle_and_the_body_point_follow_the_board_space() -> void:
	var tower := Tower.new()
	tower.col = 3
	tower.row = 5
	var at := BoardSpace.cell_to_world(3, 5)
	var muzzle := ShotsView.muzzle(tower, 0.4)
	assert_almost_eq(muzzle.x, at.x, 1e-9)
	assert_almost_eq(muzzle.z, at.z, 1e-9)
	assert_gt(muzzle.y, 0.4)
	var body := ShotsView.body_point(2.5, 7.5)
	var on_board := BoardSpace.point_to_world(2.5, 7.5)
	assert_almost_eq(body.x, on_board.x, 1e-9)
	assert_almost_eq(body.z, on_board.z, 1e-9)


func test_the_muzzle_of_a_tower_on_a_block_is_over_the_blocks_centre() -> void:
	var tower := Tower.new()
	tower.col = 3
	tower.row = 5
	var middle := BoardSpace.footprint_centre(Vector2i(3, 5), 2)
	var muzzle := ShotsView.muzzle(tower, 0.4, 2)
	assert_almost_eq(muzzle.x, middle.x, 1e-9)
	assert_almost_eq(muzzle.z, middle.z, 1e-9)


func test_a_shot_leaves_every_drawn_tower_inside_its_upper_body() -> void:
	# the muzzle follows the drawn height, so swapping a model cannot leave it inside the base
	for type in ["spoolGuard", "thimbleMortar", "prismSpire"]:
		for level in [0, 1, 2]:
			var tower := Tower.new()
			tower.type = type
			tower.level = level
			tower.col = 3
			tower.row = 5
			var view := TOWER_SCENE.instantiate() as TowerView
			add_child_autofree(view)
			view.setup(tower, TowerLooks.for_type(type), 0.0, 2)
			var muzzle := ShotsView.muzzle(tower, 0.0, 2)
			assert_gt(muzzle.y, view.body_height() * 0.5, "%s level %d" % [type, level])
			assert_lte(muzzle.y, view.body_height(), "%s level %d" % [type, level])
