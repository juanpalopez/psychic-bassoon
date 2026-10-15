## The card a tower button shows on hover or press and hold: name, role, stats, strengths.
extends GutTest

const TOWERS := preload("res://content/towers.gd")
const GUIDE := preload("res://content/guide.gd")


func _card() -> TowerCard:
	var card := TowerCard.new()
	add_child_autofree(card)
	return card


func test_it_is_hidden_until_it_has_a_tower_to_show() -> void:
	var card := _card()
	assert_false(card.visible)
	assert_eq(card.shown_id(), "")


func test_it_shows_the_name_role_stats_and_what_it_is_good_and_weak_at() -> void:
	var card := _card()
	card.show_for("thimbleMortar")
	assert_true(card.visible)
	assert_eq(card.shown_id(), "thimbleMortar")
	for part in [
		TOWERS.DEFS.thimbleMortar.name,
		GUIDE.TOWERS.thimbleMortar.role,
		GuideText.stats(TOWERS.DEFS.thimbleMortar),
		GUIDE.TOWERS.thimbleMortar.strong,
		GUIDE.TOWERS.thimbleMortar.weak
	]:
		assert_string_contains(card.text(), part)


func test_hiding_clears_it_and_it_never_blocks_a_tap() -> void:
	var card := _card()
	card.show_for("spoolGuard")
	card.hide_card()
	assert_false(card.visible)
	assert_eq(card.shown_id(), "")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_every_tower_can_be_shown() -> void:
	var card := _card()
	for id in TOWERS.TOWER_IDS:
		card.show_for(id)
		assert_string_contains(card.text(), TOWERS.DEFS[id].name)
