## The diorama on the 40 by 24 layout valley (#480): the same triangle caps as the game board,
## 30 cells of world past every edge, and no edge of the world in view from the camera.
extends GutTest

const DIORAMA_TEST := preload("res://tests/render/test_diorama.gd")
## The screen shapes the camera frames for: a 16:9 screen, a tall phone, a 4:3 tablet.
const ASPECTS: Array[float] = [16.0 / 9.0, 19.5 / 9.0, 4.0 / 3.0]
const SEEDS: Array[int] = [1, 2, 3, 5]


## The board is static, so a test that names another board gives the game board back.
func after_each() -> void:
	BoardSpace.reset()


## One board in the tree at a time: the board's size is shared.
func _layout_board(map_seed: int) -> Board:
	var board := Board.new()
	board.build_on_ready = false
	add_child(board)
	board.show_map(MapGen.generate_layout_valley(map_seed))
	return board


func test_the_layout_valley_keeps_to_the_game_boards_triangle_caps() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		assert_eq(BoardSpace.size(), Vector2(40.0, 24.0))
		var diorama := board.diorama
		var terraces := diorama.builder("Terraces")
		var ground: int = (
			terraces.triangles
			+ diorama.builder("Water").triangles
			+ diorama.builder("RoadBeds").triangles
		)
		var label := "layout seed %d" % map_seed
		(
			gut
			. p(
				(
					"%s: terraces %d triangles in %d chunks, terrain and road beds %d, scatter %d; %d surfaces"
					% [
						label,
						terraces.triangles,
						terraces.surfaces,
						ground,
						diorama.builder("Scatter").triangles,
						diorama.surface_count(),
					]
				)
			)
		)
		assert_lte(ground, DIORAMA_TEST.TERRAIN_TRIANGLES, label + ": terrain and road beds")
		assert_lte(
			diorama.builder("Scatter").triangles,
			DIORAMA_TEST.SCENERY_TRIANGLES,
			label + ": scenery"
		)
		assert_lte(diorama.surface_count(), DIORAMA_TEST.LAYOUT_SURFACES, label + ": surfaces")
		board.free()


func test_the_world_carries_on_at_least_30_cells_past_every_edge_of_the_layout_valley() -> void:
	for map_seed in SEEDS:
		var map := MapGen.generate_layout_valley(map_seed)
		var rect := TerrainField.from_map(map).world_rect()
		var half := Vector2(float(map.cols), float(map.rows)) / 2.0
		for k in 2:
			assert_lte(rect.position[k], -half[k] - 30.0, "seed %d" % map_seed)
			assert_gte(rect.end[k], half[k] + 30.0, "seed %d" % map_seed)


## The camera's real zoom, pitch, footprint and pan range (#339: the map plus its scenery margin).
func test_no_edge_of_the_world_is_in_view_on_the_game_board() -> void:
	var board := Board.new()
	board.map_seed = 1
	add_child(board)
	_check_no_edge(board)
	board.free()


func test_no_edge_of_the_world_is_in_view_on_the_layout_valley() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		_check_no_edge(board)
		board.free()


func _check_no_edge(board: Board) -> void:
	var rect := board.diorama.field.world_rect().grow(-2.0)
	var rig := CameraRig.new()
	rig.canvas_height = 720.0
	add_child_autofree(rig)
	for aspect in ASPECTS:
		rig.frame(aspect)
		for step in 11:
			rig.set_zoom(float(step) / 10.0)
			var range := rig.pan_range()
			var distance: float = rig._distance()
			var foot := CameraRig.footprint(
				distance,
				CameraRig.pitch_for(rig.zoom),
				rig.fov_degrees,
				aspect,
				CameraRig.YAW_DEGREES
			)
			# overscroll is rubber-banded: a drag past the limit gets only `RUBBER` of it through
			var slack := Vector2.ONE * 3.0 * CameraRig.RUBBER
			var pans: Array[Vector2] = [
				range.position - slack,
				range.end + slack,
				Vector2(range.position.x, range.end.y) + Vector2(-slack.x, slack.y),
				Vector2(range.end.x, range.position.y) + Vector2(slack.x, -slack.y),
			]
			for corner in pans:
				var seen := Rect2(foot.position + corner, foot.size)
				assert_true(
					rect.encloses(seen),
					"aspect %.2f zoom %.1f sees %s past %s" % [aspect, rig.zoom, seen, rect]
				)
