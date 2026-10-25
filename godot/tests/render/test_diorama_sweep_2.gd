## The layout valley's diorama keeps to the caps on seeds 51 to 100 (#523; see `diorama_sweep.gd`).
extends "res://tests/render/diorama_sweep.gd"


func test_seeds_51_to_100_keep_to_the_terrain_scenery_and_surface_caps() -> void:
	sweep(51, 100)
