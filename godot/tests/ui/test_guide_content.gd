## The words of the tour and of the tower guide.
extends GutTest

const GUIDE := preload("res://content/guide.gd")
const TOWERS := preload("res://content/towers.gd")


func test_the_tour_has_a_few_steps_each_with_a_title_and_text() -> void:
	assert_between(GUIDE.TOUR_STEPS.size(), 5, 8)
	for step in GUIDE.TOUR_STEPS:
		assert_ne(step.title, "")
		assert_gt(step.text.length(), 30, step.title)
		assert_true(step.has("target"))


func test_the_tour_covers_the_goal_building_waves_and_upgrading() -> void:
	var all := ""
	for step in GUIDE.TOUR_STEPS:
		all += (step.title + " " + step.text).to_lower() + " "
	for word in ["heartstone", "socket", "buttons", "start wave", "upgrade", "sell", "tower guide"]:
		assert_true(all.contains(word), word)


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
