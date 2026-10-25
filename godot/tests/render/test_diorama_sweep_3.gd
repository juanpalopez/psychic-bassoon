## The layout valley's diorama keeps to the caps on seeds 101 to 150 (#523; see `diorama_sweep.gd`).
extends "res://tests/render/diorama_sweep.gd"


func test_seeds_101_to_150_keep_to_the_terrain_scenery_and_surface_caps() -> void:
	sweep(101, 150)
