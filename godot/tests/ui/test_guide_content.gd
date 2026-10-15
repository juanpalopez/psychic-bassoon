## The words of the tour and of the tower guide.
extends GutTest

const GUIDE := preload("res://content/guide.gd")
const TOWERS := preload("res://content/towers.gd")
const FOES := preload("res://content/foes.gd")
const RULES := preload("res://content/game_rules.gd")


func test_every_intro_step_has_text_and_a_target_field() -> void:
	for key in GUIDE.INTRO:
		assert_gt(String(GUIDE.INTRO[key].text).length(), 30, key)
		assert_true(GUIDE.INTRO[key].has("target"), key)


func test_the_intro_covers_the_goal_sockets_buttons_waves_upgrades_and_the_guide() -> void:
	var all := ""
	for key in GUIDE.INTRO:
		all += String(GUIDE.INTRO[key].text).to_lower() + " "
	for word in ["heartstone", "socket", "buttons", "start wave", "upgrade", "sell", "tower guide"]:
		assert_true(all.contains(word), word)
	assert_true(all.contains("hover"), "it tells the player how to see a tower's card")
	assert_true(all.contains("hold"))


func test_every_tower_has_a_guide_entry_with_all_four_parts() -> void:
	for id in TOWERS.TOWER_IDS:
		assert_true(GUIDE.TOWERS.has(id), id)
		for part in ["role", "strong", "weak", "tip"]:
			assert_gt(String(GUIDE.TOWERS[id][part]).length(), 10, "%s %s" % [id, part])


func test_the_guide_names_no_tower_that_does_not_exist() -> void:
	for id in GUIDE.TOWERS:
		assert_true(TOWERS.TOWER_IDS.has(id), id)


func test_the_guide_uses_the_foe_names_of_the_game() -> void:
	var all := ""
	for id in GUIDE.TOWERS:
		all += String(GUIDE.TOWERS[id].strong) + String(GUIDE.TOWERS[id].weak)
	assert_true(all.contains("Scrap Goblin"))
	assert_true(all.contains("Corrugated Orc"))


func test_the_words_match_the_rules_they_describe() -> void:
	# the first card names the number of waves to win
	assert_string_contains(GUIDE.INTRO.goal.text, "%d waves" % RULES.WIN_WAVE)
	# the guide says the Cardboard Golem cannot be blocked, and the foe data agrees
	assert_string_contains(GUIDE.TOWERS.guardTent.strong, "Cardboard Golem cannot be blocked")
	assert_false(FOES.DEFS.cardboardGolem.blockable)
	# the guide says the Prism Spire ignores armor: it is the magic damage type
	assert_string_contains(GUIDE.TOWERS.prismSpire.role, "ignores armor")
	assert_eq(TOWERS.DEFS.prismSpire.damage_type, "magic")
	assert_gt(FOES.DEFS.corrugatedOrc.armor, 0)
