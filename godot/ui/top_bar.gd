## The stats chip, a taped cardstock tag in the top-left corner: Buttons, Heartstone health
## and wave, each with its icon.
class_name TopBar
extends PanelContainer

const RULES := preload("res://content/game_rules.gd")
const COIN := preload("res://assets/icons/coin.svg")
const HEART := preload("res://assets/icons/heart.svg")

var _buttons := Label.new()
var _heartstone := Label.new()
var _wave := Label.new()
var _of_waves := Label.new()
var _texts: Array[String] = ["", "", ""]


func _ready() -> void:
	theme_type_variation = &"Chip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# as tall as the buttons in its row, so the top row lines up
	custom_minimum_size.y = HudLayout.ROW
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_add_stat(row, COIN, "Buttons", _buttons)
	row.add_child(VSeparator.new())
	_add_stat(row, HEART, "Heartstone health", _heartstone)
	row.add_child(VSeparator.new())
	var word := Label.new()
	word.text = "WAVE"
	word.theme_type_variation = &"Caption"
	row.add_child(word)
	_wave.theme_type_variation = &"ChipNumber"
	row.add_child(_wave)
	_of_waves.theme_type_variation = &"Caption"
	row.add_child(_of_waves)


## Reads the game's numbers; call it whenever they may have changed.
func show_state(game: GameState) -> void:
	_buttons.text = str(game.buttons)
	_heartstone.text = str(game.heartstone_health)
	_wave.text = str(game.wave)
	_of_waves.text = "/ %d" % RULES.WIN_WAVE
	_texts = [
		"Buttons %d" % game.buttons,
		"Heartstone %d" % game.heartstone_health,
		"Wave %d/%d" % [game.wave, RULES.WIN_WAVE],
	]


## What each stat says, in words, in order (the chip itself shows icons and numbers).
func texts() -> Array[String]:
	return _texts.duplicate()


func _add_stat(row: HBoxContainer, icon: Texture2D, label: String, number: Label) -> void:
	var picture := TextureRect.new()
	picture.texture = icon
	picture.tooltip_text = label
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(picture)
	number.theme_type_variation = &"ChipNumber"
	row.add_child(number)
