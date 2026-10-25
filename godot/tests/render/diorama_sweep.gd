## The base of the diorama budget sweep (#523): the layout valley of every seed in a range keeps to
## the owner's provisional caps (terrain and road beds, scenery, surfaces). One diorama takes about
## a second to build, so the seeds 1 to 200 are split over four scripts that run side by side.
extends GutTest

const DIORAMA_TEST := preload("res://tests/render/test_diorama.gd")


func after_each() -> void:
	BoardSpace.reset()


## Builds the layout valley's diorama for each seed from `first` to `last` and checks its caps.
func sweep(first: int, last: int) -> void:
	var worst_ground := 0
	var worst_scenery := 0
	var worst_surfaces := 0
	var checked := 0
	for map_seed in range(first, last + 1):
		var board := Board.new()
		board.build_on_ready = false
		add_child(board)
		board.show_map(MapGen.generate_layout_valley(map_seed))
		var diorama := board.diorama
		var ground: int = (
			diorama.builder("Terraces").triangles
			+ diorama.builder("Water").triangles
			+ diorama.builder("RoadBeds").triangles
		)
		var scenery: int = diorama.builder("Scatter").triangles
		var surfaces := diorama.surface_count()
		remove_child(board)
		board.free()
		checked += 1
		worst_ground = maxi(worst_ground, ground)
		worst_scenery = maxi(worst_scenery, scenery)
		worst_surfaces = maxi(worst_surfaces, surfaces)
		var label := "layout seed %d" % map_seed
		assert_lte(ground, DIORAMA_TEST.TERRAIN_TRIANGLES, label + ": terrain and road beds")
		assert_lte(scenery, DIORAMA_TEST.SCENERY_TRIANGLES, label + ": scenery")
		assert_lte(surfaces, DIORAMA_TEST.LAYOUT_SURFACES, label + ": surfaces")
	assert_eq(checked, last - first + 1, "every seed from %d to %d was checked" % [first, last])
	(
		gut
		. p(
			(
				"seeds %d to %d: most terrain and beds %d of %d, most scenery %d of %d, most surfaces %d of %d"
				% [
					first,
					last,
					worst_ground,
					DIORAMA_TEST.TERRAIN_TRIANGLES,
					worst_scenery,
					DIORAMA_TEST.SCENERY_TRIANGLES,
					worst_surfaces,
					DIORAMA_TEST.LAYOUT_SURFACES,
				]
			)
		)
	)
