## The camera's overview and pan limits follow the board in use (#480): a 40 by 24 map is
## framed from further back, and the pan limits are refitted when the map changes.
extends GutTest

const PITCH := 62.0  # the whole-board view is the most top-down one
const FOV := 20.0
const MARGIN := 1.05


## The board is static, so a test that names another board gives the game board back.
func after_each() -> void:
	BoardSpace.reset()


## Project a world point as a camera at `distance` would see it: normalised device
## coordinates, written out independently of `CameraRig.fit_distance`.
func _ndc(point: Vector3, distance: float, aspect: float) -> Vector2:
	var pitch := deg_to_rad(PITCH)
	var forward := Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var right := Vector3.RIGHT
	var camera := -forward * distance
	var offset := point - camera
	var depth := offset.dot(forward)
	var tan_v := tan(deg_to_rad(FOV) / 2.0)
	return Vector2(offset.dot(right) / (depth * tan_v * aspect), offset.dot(up) / (depth * tan_v))


func _fit(aspect: float) -> float:
	return CameraRig.fit_distance(BoardSpace.corners(), PITCH, FOV, aspect, MARGIN, 0.0)


func test_the_overview_fits_every_corner_of_a_40_by_24_board() -> void:
	BoardSpace.use_map(40, 24)
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 19.5 / 9.0]:
		var distance := _fit(aspect)
		for corner in BoardSpace.corners():
			var ndc := _ndc(corner, distance, aspect)
			assert_lte(absf(ndc.x), 1.0, "x, aspect %f" % aspect)
			assert_lte(absf(ndc.y), 1.0, "y, aspect %f" % aspect)


func test_a_bigger_board_is_framed_from_further_back() -> void:
	var game_fit := _fit(16.0 / 9.0)
	BoardSpace.use_map(40, 24)
	assert_gt(_fit(16.0 / 9.0), game_fit)


func test_the_pan_limits_follow_the_board_in_use_and_are_not_kept_from_the_last_map() -> void:
	# a rig that drew the game board refits when a 40 by 24 map is shown (no stale cache)
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.canvas_height = 720.0
	rig.frame(16.0 / 9.0)
	# at the closest zoom the pan limits are the widest (the overview has none to speak of)
	rig.set_zoom(1.0)
	var game_range := rig.pan_range()
	BoardSpace.use_map(40, 24)
	var fresh := CameraRig.new()
	add_child_autofree(fresh)
	fresh.canvas_height = 720.0
	fresh.frame(16.0 / 9.0)
	fresh.set_zoom(1.0)
	assert_eq(rig.pan_range(), fresh.pan_range())
	assert_gt(rig.pan_range().size.x, game_range.size.x)
