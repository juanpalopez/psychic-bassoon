## The stats line of a tower in the guide, read from the content.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_a_shooter_shows_cost_damage_range_and_rate() -> void:
	var def: Dictionary = TOWERS.DEFS.spoolGuard
	var text := GuideText.stats(def)
	assert_string_contains(text, str(def.cost[0]))
	assert_string_contains(text, str(def.damage[0]))
	assert_string_contains(text, str(def.range[0]))
	assert_string_contains(text, str(def.rate[0]))


func test_a_mortar_also_shows_its_blast() -> void:
	assert_string_contains(
		GuideText.stats(TOWERS.DEFS.thimbleMortar), str(TOWERS.DEFS.thimbleMortar.splash[0])
	)


func test_a_beam_is_per_second() -> void:
	assert_string_contains(GuideText.stats(TOWERS.DEFS.prismSpire), "/s")


func test_a_guard_tent_shows_its_guards_and_a_mess_tent_its_aura() -> void:
	assert_string_contains(
		GuideText.stats(TOWERS.DEFS.guardTent), str(TOWERS.DEFS.guardTent.guard_hp[0])
	)
	assert_string_contains(GuideText.stats(TOWERS.DEFS.messTent), "%")


func test_every_tower_has_a_stats_line() -> void:
	for id in TOWERS.TOWER_IDS:
		assert_gt(GuideText.stats(TOWERS.DEFS[id]).length(), 10, id)
