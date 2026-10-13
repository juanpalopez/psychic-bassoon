## Plays the music and sound effects it is told to. Browsers block audio before the
## first tap, so nothing starts until `unlock` (called on the first press); music asked
## for before that starts then. It never reads the game; the scene feeds it.
class_name AudioPlayer
extends Node

const DIRECTORY := "res://assets/audio/"
const SFX_VOICES := 8
## The same effect inside this many milliseconds plays once (a crowd of kills is one snap).
const SFX_MIN_GAP_MSEC := 60
const MUSIC_VOLUME_DB := -8.0

var _unlocked := false
var _muted := false
var _music_key := ""
var _sfx_count := 0
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_msec := {}


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	_apply_music()


func is_unlocked() -> bool:
	return _unlocked


func set_muted(value: bool) -> void:
	_muted = value
	if _music != null:
		_music.stream_paused = value


func is_muted() -> bool:
	return _muted


## How many effects started (the throttled and muted ones do not count).
func sfx_played() -> int:
	return _sfx_count


## The music key playing now, or "" before the first tap.
func playing_music() -> String:
	return _music_key if _unlocked else ""


func set_music(key: String) -> void:
	if key == _music_key:
		return
	_music_key = key
	_apply_music()


func play_sfx(key: String) -> void:
	if not _unlocked or _muted or key == "":
		return
	var now := Time.get_ticks_msec()
	if _last_msec.has(key) and now - int(_last_msec[key]) < SFX_MIN_GAP_MSEC:
		return
	_last_msec[key] = now
	var stream := _load("sfx/sfx_" + key)
	if stream == null:
		return
	_sfx_count += 1
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.play()


func _apply_music() -> void:
	if not _unlocked or _music_key == "":
		return
	var stream := _load("music/music_" + _music_key)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.stream_paused = _muted
	if stream != null:
		_music.play()


func _load(name: String) -> AudioStream:
	return load(DIRECTORY + name + ".ogg") as AudioStream
