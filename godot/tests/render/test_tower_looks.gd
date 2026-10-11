## A tower's look is a Resource saved as a .tres, editable in the Inspector. It
## holds how a tower looks and nothing else: its numbers live in godot/content.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_every_tower_has_a_look_that_loads_as_a_resource() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		assert_not_null(look, id)
		assert_true(look is TowerLook, id)
		assert_true(look is Resource)


func test_the_looks_are_saved_files_not_built_in_code() -> void:
	for id in TOWERS.TOWER_IDS:
		var path := "res://render/looks/%s.tres" % TowerLooks.file_name_for(id)
		assert_true(ResourceLoader.exists(path), path)
		assert_eq(load(path), TowerLooks.for_type(id), "the same resource")


func test_each_look_has_its_own_colour_and_sensible_sizes() -> void:
	var colours := {}
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		colours[look.body_colour] = true
		assert_gt(look.foot, 0.2, id)
		assert_lt(look.foot, 1.0, id)
		assert_gt(look.base_height, 0.3, id)
		assert_gt(look.height_per_level, 0.0, id)
	assert_eq(colours.size(), TOWERS.TOWER_IDS.size(), "four colours, none repeated")


func test_a_look_holds_no_game_numbers() -> void:
	# the properties of a look are only visual
	var names := []
	for property in TowerLooks.for_type("ballista").get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(property.name)
	for forbidden in ["cost", "damage", "range", "rate", "splash", "slow", "chain"]:
		assert_false(names.has(forbidden), forbidden)


func test_an_unknown_tower_gets_a_fallback_look() -> void:
	var look := TowerLooks.for_type("laser")
	assert_not_null(look)
	assert_true(look is TowerLook)
