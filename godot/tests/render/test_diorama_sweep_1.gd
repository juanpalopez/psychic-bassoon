## The layout valley's diorama keeps to the caps on seeds 1 to 50 (#523; see `diorama_sweep.gd`).
extends "res://tests/render/diorama_sweep.gd"


func test_seeds_1_to_50_keep_to_the_terrain_scenery_and_surface_caps() -> void:
	sweep(1, 50)
