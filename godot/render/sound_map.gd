## Which sound a game event or the game's state calls for. Pure mapping: it reads, it
## never plays.
class_name SoundMap
extends RefCounted

const WAVES := preload("res://content/waves.gd")
## Sound effect keys (`assets/audio/sfx/sfx_<key>.ogg`).
const SFX_KEYS: Array[String] = [
	"scissor_snap",
	"twang_spool_guard",
	"twang_thimble_mortar",
	"glass_chime_prism",
	"stamp_ui_confirm",
	"paper_tear",
	"paper_tear_short",
	"metal_snap",
	"cardstock_fold",
	"thimble_clink",
	"stamp_thud_boss_step",
]
## Music keys (`assets/audio/music/music_<name>.ogg`).
const MUSIC_FILES: Array[String] = ["tier1_planning", "tier2_wave", "tier3_boss"]
const FIRE_SOUNDS := {
	"spoolGuard": "twang_spool_guard",
	"thimbleMortar": "twang_thimble_mortar",
	"prismSpire": "glass_chime_prism",
}
const EVENT_SOUNDS := {
	GameEvent.Kind.TOWER_BUILT: "stamp_ui_confirm",
	GameEvent.Kind.TOWER_UPGRADED: "stamp_ui_confirm",
	GameEvent.Kind.TOWER_SOLD: "paper_tear",
	GameEvent.Kind.COMMAND_REJECTED: "metal_snap",
	GameEvent.Kind.WAVE_LAUNCHED: "cardstock_fold",
	GameEvent.Kind.FOE_KILLED: "scissor_snap",
	GameEvent.Kind.FOE_LEAKED: "paper_tear_short",
	GameEvent.Kind.GUARD_FELL: "thimble_clink",
}
const BOSS_FOE := "cardboardGolem"


## The sound key of an event, or "" when it is silent.
static func sfx_for(event: GameEvent, game: GameState) -> String:
	if event.kind == GameEvent.Kind.TOWER_FIRED:
		for tower in game.towers:
			if tower.id == event.tower_id:
				return FIRE_SOUNDS.get(tower.type, "")
		return ""
	if event.kind == GameEvent.Kind.FOE_SPAWNED:
		return "stamp_thud_boss_step" if event.foe_type == BOSS_FOE else ""
	return EVENT_SOUNDS.get(event.kind, "")


## The music key for the game's state: the boss tune on a boss wave while it runs, the wave
## tune while a wave runs, and the planning tune otherwise.
static func music_for(game: GameState) -> String:
	if game.running and not game.over and not game.won:
		return "tier3_boss" if game.wave % WAVES.BOSS_EVERY == 0 else "tier2_wave"
	return "tier1_planning"
