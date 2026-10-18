## Tower attacks: darts and pellets in flight with a pop or a confetti burst.
extends GutTest

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


func test_a_shot_is_drawn_landing_on_the_first_frame_after_its_flight() -> void:
	var flight := ShotsView.flight_of(ShotsView.Kind.DART, FROM, TO)
	var lands := ShotsView.landing_of(ShotsView.Kind.DART, FROM, TO)
	assert_almost_eq(lands, ceilf(flight * ShotsView.FPS) / ShotsView.FPS, 1e-6)
	var view := _view()
	view.add_shot(FROM, TO, 0.0)
	view.update(lands - 0.01)
	assert_true(view.shot_body(0).visible, "still flying just before")
	view.update(0.01)
	assert_false(view.shot_body(0).visible, "landed then")
	assert_almost_eq(
		ShotsView.landing_of(ShotsView.Kind.PELLET, FROM, TO), ShotsView.PELLET_SECONDS, 1e-6
	)


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


func test_the_thimble_mortar_lobs_pellets_and_every_other_tower_throws_darts() -> void:
	assert_eq(ShotsView.kind_for("thimbleMortar"), ShotsView.Kind.PELLET)
	assert_eq(ShotsView.kind_for("spoolGuard"), ShotsView.Kind.DART)
	assert_eq(ShotsView.kind_for("prismSpire"), ShotsView.Kind.DART)


func test_a_pellet_lives_longest_and_no_shot_outlives_the_shot_seconds() -> void:
	var dart := ShotsView.life_of(ShotsView.Kind.DART, FROM, FROM + Vector3(40, 0, 0))
	var pellet := ShotsView.life_of(ShotsView.Kind.PELLET, FROM, TO)
	assert_lte(dart, ShotsView.SHOT_SECONDS + 1e-6)
	assert_almost_eq(pellet, ShotsView.SHOT_SECONDS, 1e-6)


func test_a_pellet_is_on_an_arc_over_the_straight_line() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95, ShotsView.Kind.PELLET)
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


func test_a_pellet_in_flight_is_drawn_on_its_arc_and_goes_when_it_lands() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95, ShotsView.Kind.PELLET)
	var ball := view.shot_body(0)
	view.update(2.0 / ShotsView.FPS + 1e-4)
	var share := (2.0 / ShotsView.FPS) / ShotsView.PELLET_SECONDS
	var expected := ShotsView.point_on_flight(ShotsView.Kind.PELLET, FROM, TO, share)
	assert_true(ball.visible)
	assert_almost_eq(ball.position.distance_to(expected), 0.0, 1e-4)
	assert_gt(ball.position.y, FROM.lerp(TO, share).y + 0.5, "above the straight line")
	view.update(ShotsView.PELLET_SECONDS)
	assert_false(ball.visible, "it has landed")
	assert_true(view.shot_burst(0).visible, "and burst")


func test_a_landing_pellet_bursts_in_a_ring_as_wide_as_its_splash() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.95, ShotsView.Kind.PELLET)
	view.update(ShotsView.PELLET_SECONDS + ShotsView.BURST_SECONDS * 0.99)
	var ring := view.shot_ring(0)
	assert_true(ring.visible)
	assert_almost_eq(ring.position.x, TO.x, 1e-5)
	assert_almost_eq(ring.position.z, TO.z, 1e-5)
	assert_between(ring.scale.x, 0.95 * 0.55, 0.95 + 1e-5)
	assert_true(view.shot_burst(0).visible, "confetti")
	view.update(ShotsView.BURST_SECONDS)
	assert_false(ring.visible)


func test_a_dart_bomb_stays_a_dart_and_rings_as_wide_as_its_splash() -> void:
	var view := _view()
	view.add_shot(FROM, TO, 0.6, ShotsView.Kind.DART)
	assert_eq(view.shot_kind(0), ShotsView.Kind.DART, "the Aviary's bombs are darts")
	# the first stepped frame past its flight
	view.update(ShotsView.flight_of(ShotsView.Kind.DART, FROM, TO) + 1.0 / ShotsView.FPS)
	var ring := view.shot_ring(0)
	assert_true(ring.visible)
	assert_between(ring.scale.x, 0.6 * 0.55, 0.6 + 1e-5)


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
	var dart := view.shot_body(0)
	assert_true(dart.visible)
	assert_almost_eq(dart.basis.z.normalized().dot(Vector3.UP), 1.0, 1e-4, "it points up")
	assert_gt(absf(dart.basis.determinant()), 0.1, "a whole basis, not a flat one")


func test_the_dart_is_the_spool_guards_own_dart() -> void:
	var view := _view()
	var mesh := view.shot_body(0).mesh
	assert_false(mesh is BoxMesh, "the model's dart, not the fallback box")
	assert_true(mesh.surface_get_material(0) is ShaderMaterial)
