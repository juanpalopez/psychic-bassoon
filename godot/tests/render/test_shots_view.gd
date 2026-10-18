## Tower attacks: darts and pellets in flight with a pop or a confetti burst, and beams.
extends GutTest

const TOWER_SCENE := preload("res://render/tower_view.tscn")
const FROM := Vector3(1.0, 1.0, 2.0)
const TO := Vector3(4.0, 0.5, -2.0)


func _view() -> ShotsView:
	var view := ShotsView.new()
	add_child_autofree(view)
	return view


func test_a_dart_starts_at_the_tower_and_points_at_the_target() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	assert_eq(view.visible_shots(), 1)
	assert_eq(view.shot_kind(0), ShotsView.Kind.DART)
	assert_eq(view.drawn_from(0), FROM)
	assert_eq(view.drawn_to(0), TO)
	var dart := view.shot_body(0)
	assert_true(dart.visible)
	assert_almost_eq(dart.position.distance_to(FROM), 0.0, 1e-5)
	# the dart's tip (the model's +Z) points along the shot
	assert_almost_eq(dart.basis.z.normalized().dot((TO - FROM).normalized()), 1.0, 1e-4)


func test_a_dart_flies_in_stop_motion_steps_and_reaches_the_target() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	var dart := view.shot_body(0)
	view.update(0.5 / ShotsView.FPS)
	assert_almost_eq(dart.position.distance_to(FROM), 0.0, 1e-5, "it holds until the next frame")
	view.update(0.6 / ShotsView.FPS)
	var flight := ShotsView.flight_of(ShotsView.Kind.DART, FROM, TO)
	var expected := FROM.lerp(TO, (1.0 / ShotsView.FPS) / flight)
	assert_almost_eq(dart.position.distance_to(expected), 0.0, 1e-4, "one frame along")
	view.update(flight)
	assert_false(dart.visible, "it has hit")
	assert_true(view.shot_burst(0).visible, "and popped into scraps")
	assert_almost_eq(view.shot_burst(0).position.x, TO.x, 1e-4)


func test_a_dart_flies_between_two_and_four_frames() -> void:
	var near := ShotsView.flight_of(ShotsView.Kind.DART, FROM, FROM + Vector3(0.1, 0, 0))
	var far := ShotsView.flight_of(ShotsView.Kind.DART, FROM, FROM + Vector3(40, 0, 0))
	assert_almost_eq(near, 2.0 / 12.0, 1e-6)
	assert_almost_eq(far, 4.0 / 12.0, 1e-6)


func test_a_shot_goes_after_its_flight_and_its_pop() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	var life := ShotsView.life_of(ShotsView.Kind.DART, FROM, TO)
	view.update(life - 0.01)
	assert_eq(view.visible_shots(), 1)
	view.update(0.02)
	assert_eq(view.visible_shots(), 0)
	assert_false(view.shot_body(0).visible)
	assert_false(view.shot_burst(0).visible)
	assert_lte(life, ShotsView.SHOT_SECONDS + 1e-6)


func test_a_blast_is_a_pellet_on_an_arc_over_the_straight_line() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95)
	assert_eq(view.shot_kind(0), ShotsView.Kind.PELLET)
	var middle := ShotsView.point_on_flight(ShotsView.Kind.PELLET, FROM, TO, 0.5)
	assert_gt(middle.y, maxf(FROM.y, TO.y) + 0.5, "it is lobbed high")
	assert_almost_eq(
		ShotsView.point_on_flight(ShotsView.Kind.PELLET, FROM, TO, 0.0).distance_to(FROM), 0.0, 1e-6
	)
	assert_almost_eq(
		ShotsView.point_on_flight(ShotsView.Kind.PELLET, FROM, TO, 1.0).distance_to(TO), 0.0, 1e-6
	)
	assert_false(view.shot_ring(0).visible, "no ring until it lands")


func test_a_landing_pellet_bursts_in_a_ring_as_wide_as_its_splash() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95)
	view.update(ShotsView.PELLET_SECONDS + ShotsView.BURST_SECONDS * 0.99)
	var ring := view.shot_ring(0)
	assert_true(ring.visible)
	assert_almost_eq(ring.position.x, TO.x, 1e-5)
	assert_almost_eq(ring.position.z, TO.z, 1e-5)
	assert_between(ring.scale.x, 0.95 * 0.55, 0.95 + 1e-5)
	assert_true(view.shot_burst(0).visible, "confetti")
	view.update(ShotsView.BURST_SECONDS)
	assert_false(ring.visible)


func test_a_single_target_shot_has_no_ring() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	view.update(ShotsView.DART_MAX)
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
	assert_true(view.shot_body(0).visible)


func test_the_dart_is_the_spool_guards_own_dart() -> void:
	var view := _view()
	var mesh := view.shot_body(0).mesh
	assert_false(mesh is BoxMesh, "the model's dart, not the fallback box")
	assert_true(mesh.surface_get_material(0) is ShaderMaterial)


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
