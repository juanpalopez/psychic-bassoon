## Which sound a game event or state calls for. Pure mapping, no playback.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _game_with_tower(type: String) -> GameState:
	var game := Game.create(42)
	var tower := Tower.new()
	tower.id = 7
	tower.type = type
	game.towers.append(tower)
	return game


func _fired(tower_id: int) -> GameEvent:
	var event := GameEvent.of(GameEvent.Kind.TOWER_FIRED)
	event.tower_id = tower_id
	return event


func test_each_tower_type_fires_its_own_sound() -> void:
	assert_eq(SoundMap.sfx_for(_fired(7), _game_with_tower("spoolGuard")), "twang_spool_guard")
	assert_eq(
		SoundMap.sfx_for(_fired(7), _game_with_tower("thimbleMortar")), "twang_thimble_mortar"
	)
	assert_eq(SoundMap.sfx_for(_fired(7), _game_with_tower("prismSpire")), "glass_chime_prism")


func test_a_shot_from_a_tower_that_is_gone_is_silent() -> void:
	assert_eq(SoundMap.sfx_for(_fired(99), _game_with_tower("spoolGuard")), "")


func test_building_upgrading_selling_and_refusing_have_sounds() -> void:
	var game := Game.create(42)
	var expected := {
		GameEvent.Kind.TOWER_BUILT: "stamp_ui_confirm",
		GameEvent.Kind.TOWER_UPGRADED: "stamp_ui_confirm",
		GameEvent.Kind.TOWER_SOLD: "paper_tear",
		GameEvent.Kind.COMMAND_REJECTED: "metal_snap",
		GameEvent.Kind.WAVE_LAUNCHED: "cardstock_fold",
		GameEvent.Kind.FOE_KILLED: "scissor_snap",
		GameEvent.Kind.FOE_LEAKED: "paper_tear_short",
		GameEvent.Kind.GUARD_FELL: "thimble_clink",
	}
	for kind in expected:
		assert_eq(SoundMap.sfx_for(GameEvent.of(kind), game), expected[kind], str(kind))


func test_the_golem_walking_in_is_a_boss_step_and_other_foes_are_silent() -> void:
	var game := Game.create(42)
	var golem := GameEvent.of(GameEvent.Kind.FOE_SPAWNED)
	golem.foe_type = "cardboardGolem"
	assert_eq(SoundMap.sfx_for(golem, game), "stamp_thud_boss_step")
	var goblin := GameEvent.of(GameEvent.Kind.FOE_SPAWNED)
	goblin.foe_type = "scrapGoblin"
	assert_eq(SoundMap.sfx_for(goblin, game), "")


func test_events_without_a_sound_are_silent() -> void:
	var game := Game.create(42)
	for kind in [
		GameEvent.Kind.FOE_ENGAGED, GameEvent.Kind.GUARD_RAISED, GameEvent.Kind.WAVE_CLEARED
	]:
		assert_eq(SoundMap.sfx_for(GameEvent.of(kind), game), "", str(kind))


func test_music_follows_the_state() -> void:
	var game := Game.create(42)
	assert_eq(SoundMap.music_for(game), "tier1_planning", "before the first wave")
	game.running = true
	game.wave = 3
	assert_eq(SoundMap.music_for(game), "tier2_wave")
	game.wave = WAVES.BOSS_EVERY
	assert_eq(SoundMap.music_for(game), "tier3_boss")
	game.running = false
	assert_eq(SoundMap.music_for(game), "tier1_planning", "between waves")
	game.running = true
	game.over = true
	assert_eq(SoundMap.music_for(game), "tier1_planning", "after the game")


func test_every_named_sound_has_a_file() -> void:
	var names: Array[String] = []
	for name in SoundMap.SFX_KEYS:
		names.append("sfx/sfx_" + name)
	for name in SoundMap.MUSIC_FILES:
		names.append("music/music_" + name)
	for name in names:
		assert_true(ResourceLoader.exists("res://assets/audio/" + name + ".ogg"), name)


func test_every_sound_the_map_can_return_is_a_known_key() -> void:
	var game := _game_with_tower("spoolGuard")
	var returned: Array[String] = []
	returned.append_array(SoundMap.FIRE_SOUNDS.values())
	returned.append_array(SoundMap.EVENT_SOUNDS.values())
	returned.append("stamp_thud_boss_step")
	for key in returned:
		assert_true(key in SoundMap.SFX_KEYS, key)
	assert_eq(game.towers.size(), 1)
