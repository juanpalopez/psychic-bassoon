## The towers the GDD's combat slice starts with: Spool Guard, Thimble Mortar
## and Prism Spire. The prototype's ids are gone from the code.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_the_three_combat_towers_in_build_order() -> void:
	assert_eq(TOWERS.TOWER_IDS, ["spoolGuard", "thimbleMortar", "prismSpire"])
	assert_eq(TOWERS.DEFS.keys().size(), 3)
	for id in TOWERS.TOWER_IDS:
		assert_true(TOWERS.DEFS.has(id), id)


func test_display_names_are_the_gdds() -> void:
	assert_eq(TOWERS.DEFS.spoolGuard.name, "Spool Guard")
	assert_eq(TOWERS.DEFS.thimbleMortar.name, "Thimble Mortar")
	assert_eq(TOWERS.DEFS.prismSpire.name, "Prism Spire")


func test_every_tower_has_three_levels_of_cost_damage_and_range() -> void:
	for id in TOWERS.TOWER_IDS:
		for key in ["cost", "damage", "range"]:
			assert_eq(TOWERS.DEFS[id][key].size(), 3, "%s %s" % [id, key])


func test_each_level_costs_a_whole_number_of_buttons_and_hits_harder_and_further() -> void:
	for id in TOWERS.TOWER_IDS:
		var def: Dictionary = TOWERS.DEFS[id]
		for level in 2:
			assert_gt(def.damage[level + 1], def.damage[level], "%s damage" % id)
			assert_gt(def.range[level + 1], def.range[level], "%s range" % id)
		for cost in def.cost:
			assert_true(cost is int and cost > 0, id)


func test_the_numbers_start_from_the_prototype() -> void:
	# the Spool Guard is the prototype's Ballista, the Mortar its Catapult
	assert_eq(TOWERS.DEFS.spoolGuard.cost, [50, 60, 110])
	assert_eq(TOWERS.DEFS.spoolGuard.damage, [9, 15, 26])
	assert_eq(TOWERS.DEFS.spoolGuard.rate, [3.0, 3.6, 4.5])
	assert_eq(TOWERS.DEFS.thimbleMortar.cost, [90, 90, 160])
	assert_eq(TOWERS.DEFS.thimbleMortar.splash, [0.95, 1.15, 1.35])


func test_the_spool_guard_and_mortar_fire_shots_and_have_a_rate() -> void:
	for id in ["spoolGuard", "thimbleMortar"]:
		assert_eq(TOWERS.DEFS[id].rate.size(), 3, id)
		assert_false(TOWERS.DEFS[id].has("beam"), id)


func test_the_prism_spire_is_a_beam_with_damage_per_second_and_no_rate() -> void:
	var def: Dictionary = TOWERS.DEFS.prismSpire
	assert_true(def.beam)
	assert_false(def.has("rate"))
	# the Storm Spire's damage times its rate, rounded: 18 * 0.9, 30 * 1.1, 50 * 1.3
	assert_eq(def.damage, [16, 33, 65])
	assert_eq(def.cost, [110, 100, 180])
	assert_eq(def.range, [2.3, 2.6, 2.9])


func test_no_dropped_tower_has_a_leftover_stat() -> void:
	for id in TOWERS.TOWER_IDS:
		assert_false(TOWERS.DEFS[id].has("chain"), id)
		assert_false(TOWERS.DEFS[id].has("slow"), id)


func test_no_old_tower_id_is_left_in_the_code_or_looks() -> void:
	# built from pieces so this file does not contain them itself
	var old: Array[String] = [
		"ball" + "ista", "cata" + "pult", "frost" + "Spire", "storm" + "Spire"
	]
	var old_files: Array[String] = ["frost" + "_spire", "storm" + "_spire"]
	var found: Array[String] = []
	for dir in ["res://content", "res://sim", "res://render", "res://ui", "res://tests"]:
		_scan(dir, old, old_files, found)
	assert_eq(found, [], "old ids")


func _scan(dir: String, old: Array[String], old_files: Array[String], found: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, old, old_files, found)
	for file in DirAccess.get_files_at(dir):
		for name in old_files:
			if file.contains(name):
				found.append(dir + "/" + file)
		if not (file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn")):
			continue
		if file == "test_tower_content.gd":
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + file)
		for id in old:
			if text.contains(id):
				found.append("%s/%s has %s" % [dir, file, id])
