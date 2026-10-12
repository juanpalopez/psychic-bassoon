## Tower shots and beams, drawn as short-lived lines (and a ring for a blast).
extends GutTest

const FROM := Vector3(1.0, 1.0, 2.0)
const TO := Vector3(4.0, 0.5, -2.0)


func _view() -> ShotsView:
	var view := ShotsView.new()
	add_child_autofree(view)
	return view


func test_a_shot_draws_a_line_from_the_tower_to_the_target() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	assert_eq(view.visible_shots(), 1)
	assert_eq(view.drawn_from(0), FROM)
	assert_eq(view.drawn_to(0), TO)
	var line := view.shot_line(0)
	assert_true(line.visible)
	assert_almost_eq(line.position.x, (FROM.x + TO.x) / 2.0, 1e-5)
	assert_almost_eq(line.position.y, (FROM.y + TO.y) / 2.0, 1e-5)
	assert_almost_eq(line.position.z, (FROM.z + TO.z) / 2.0, 1e-5)
	# the box is one unit long and stretched to the distance
	assert_almost_eq(line.basis.get_scale().z, FROM.distance_to(TO), 1e-4)
	# and it points along the shot
	var along := -line.basis.z.normalized()
	assert_almost_eq(along.dot((TO - FROM).normalized()), 1.0, 1e-5)


func test_a_shot_expires_after_its_time() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	view.update(ShotsView.SHOT_SECONDS * 0.5)
	assert_eq(view.visible_shots(), 1)
	view.update(ShotsView.SHOT_SECONDS * 0.6)
	assert_eq(view.visible_shots(), 0)
	assert_false(view.shot_line(0).visible)


func test_a_blast_draws_a_ring_as_wide_as_its_splash_at_the_target() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95)
	var ring := view.shot_ring(0)
	assert_true(ring.visible)
	assert_almost_eq(ring.position.x, TO.x, 1e-5)
	assert_almost_eq(ring.position.z, TO.z, 1e-5)
	assert_almost_eq(ring.scale.x, 0.95, 1e-5)
	assert_almost_eq(ring.scale.z, 0.95, 1e-5)
	view.update(ShotsView.SHOT_SECONDS * 2.0)
	assert_false(ring.visible)


func test_a_single_target_shot_has_no_ring() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	assert_false(view.shot_ring(0).visible)


func test_shots_beyond_the_pool_reuse_the_oldest_and_never_add_nodes() -> void:
	var view := _view()
	var nodes := view.get_child_count()
	for i in ShotsView.MAX_SHOTS * 2:
		view.add_shot(FROM, TO + Vector3(float(i), 0.0, 0.0), 0.0)
	assert_eq(view.get_child_count(), nodes)
	assert_eq(view.visible_shots(), ShotsView.MAX_SHOTS)


func test_a_shot_with_no_length_draws_nothing() -> void:
	var view := _view()
	view.add_shot(FROM, FROM, 0.0)
	assert_eq(view.visible_shots(), 0)


func test_a_straight_up_shot_still_draws() -> void:
	var view := _view()
	view.add_shot(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 3.0, 0.0), 0.0)
	assert_eq(view.visible_shots(), 1)
	assert_almost_eq(view.shot_line(0).basis.get_scale().z, 3.0, 1e-4)


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
	assert_eq(view.beam_from(0), ShotsView.muzzle(scene.tower, 0.3))


func test_a_beam_goes_when_its_lock_goes() -> void:
	var made := _beam_game()
	var scene: TowerFireKit.Scene = made[0]
	var view := _view()
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 1)
	assert_true(view.beam_line(0).visible)
	scene.tower.target_id = -1
	view.show_beams(scene.game, Callable())
	assert_eq(view.visible_beams(), 0)
	assert_false(view.beam_line(0).visible, "the line is hidden, not just uncounted")


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
