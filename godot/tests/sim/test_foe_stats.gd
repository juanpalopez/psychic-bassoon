## A foe's numbers for a wave: the base numbers, scaled up. The expected values
## are written out by hand from the formulas, not read from the constants.
extends GutTest

const FOES := preload("res://content/foes.gd")


func test_the_three_ground_foes_have_the_gdd_roles() -> void:
	assert_eq(FOES.FOE_IDS, ["scrapGoblin", "corrugatedOrc", "cardboardGolem"] as Array[String])
	# swarm: fast and frail; armored: slow and tough; boss: huge and slower still
	var goblin: Dictionary = FOES.DEFS.scrapGoblin
	var orc: Dictionary = FOES.DEFS.corrugatedOrc
	var golem: Dictionary = FOES.DEFS.cardboardGolem
	assert_gt(goblin.speed, orc.speed)
	assert_lt(goblin.hp, orc.hp)
	assert_eq(goblin.armor, 0)
	assert_gt(orc.armor, 0)
	assert_gt(golem.hp, orc.hp * 3)
	assert_eq(golem.splits_into, "scrapGoblin")
	assert_gt(golem.split_count, 0)


func test_wave_1_is_the_base_foe_with_a_hair_more_speed() -> void:
	var stats := FoeStats.for_wave("scrapGoblin", 1)
	assert_eq(stats.hp, 20)
	assert_almost_eq(stats.speed, 1.9 * 1.006, 1e-12)
	assert_eq(stats.reward, 4)
	assert_eq(stats.armor, 0)


func test_wave_10_goblin() -> void:
	# n = 9: hp scale 1 + 0.2 * 9 + 0.04 * 81 = 6.04, so 20 * 6.04 = 120.8
	var stats := FoeStats.for_wave("scrapGoblin", 10)
	assert_eq(stats.hp, 121)
	assert_almost_eq(stats.speed, 1.9 * 1.06, 1e-12)
	# 4 * (1 + 0.04 * 9) = 5.44
	assert_eq(stats.reward, 5)
	assert_eq(stats.armor, 0)


func test_wave_24_orc() -> void:
	# n = 23: scale 1 + 4.6 + 0.04 * 529 = 26.76, so 130 * 26.76 = 3478.8
	var stats := FoeStats.for_wave("corrugatedOrc", 24)
	assert_eq(stats.hp, 3479)
	assert_almost_eq(stats.speed, 0.68 * 1.144, 1e-12)
	# 13 * (1 + 0.04 * 23) = 24.96
	assert_eq(stats.reward, 25)
	# an extra armor point every 12 waves: 6 + 2
	assert_eq(stats.armor, 8)


func test_speed_bonus_stops_at_the_cap() -> void:
	# 0.006 * 100 would be 0.6; the cap is 0.25
	assert_almost_eq(FoeStats.for_wave("cardboardGolem", 100).speed, 0.5 * 1.25, 1e-12)
	assert_almost_eq(FoeStats.for_wave("cardboardGolem", 41).speed, 0.5 * 1.246, 1e-12)
	assert_almost_eq(FoeStats.for_wave("cardboardGolem", 42).speed, 0.5 * 1.25, 1e-12)


func test_armor_steps_up_every_12_waves() -> void:
	assert_eq(FoeStats.for_wave("corrugatedOrc", 11).armor, 6)
	assert_eq(FoeStats.for_wave("corrugatedOrc", 12).armor, 7)
	assert_eq(FoeStats.for_wave("corrugatedOrc", 23).armor, 7)
	assert_eq(FoeStats.for_wave("corrugatedOrc", 24).armor, 8)


func test_a_stronger_wave_never_makes_a_foe_weaker() -> void:
	for id in FOES.FOE_IDS:
		var previous := FoeStats.for_wave(id, 1)
		for wave in range(2, 60):
			var stats := FoeStats.for_wave(id, wave)
			assert_gte(stats.hp, previous.hp, "%s hp, wave %d" % [id, wave])
			assert_gte(stats.speed, previous.speed, "%s speed, wave %d" % [id, wave])
			assert_gte(stats.reward, previous.reward, "%s reward, wave %d" % [id, wave])
			assert_gte(stats.armor, previous.armor, "%s armor, wave %d" % [id, wave])
			previous = stats


func test_an_unknown_foe_is_reported_and_gives_nothing() -> void:
	assert_null(FoeStats.for_wave("laser", 1))
	assert_push_error("unknown foe laser")
