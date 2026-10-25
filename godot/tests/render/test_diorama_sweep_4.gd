## The layout valley's diorama keeps to the caps on seeds 151 to 200 (#523; see `diorama_sweep.gd`).
extends "res://tests/render/diorama_sweep.gd"


func test_seeds_151_to_200_keep_to_the_terrain_scenery_and_surface_caps() -> void:
	sweep(151, 200)
