## Pause, and one button that cycles the speed 1x, 2x, 3x: square cardstock buttons in the
## top-right corner. It does not touch the game: it announces the choice and shows which
## speed is active.
class_name SpeedBar
extends HBoxContainer

signal speed_chosen(speed: int)
signal pause_toggled

const SQUARE := Vector2(88.0, 88.0)
const PAUSE_ICON := preload("res://assets/icons/pause.svg")
const PLAY_ICON := preload("res://assets/icons/play.svg")

var _pause: Button
var _cycle: Button
var _speed := GameSpeed.SPEEDS[0]


func _ready() -> void:
	_pause = _add_button("Pause", &"IconButton")
	_pause.icon = PAUSE_ICON
	_pause.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.tooltip_text = "Pause"
	_pause.pressed.connect(func() -> void: pause_toggled.emit())
	_cycle = _add_button("%dx" % _speed, &"SpeedButton")
	_cycle.toggle_mode = false
	_cycle.tooltip_text = "Game speed"
	_cycle.pressed.connect(func() -> void: speed_chosen.emit(next_speed()))


## Pause first, then the speed button.
func buttons() -> Array[Button]:
	return [_pause, _cycle]


## The speed a press of the speed button would choose: the one after the shown speed,
## back to the first after the last.
func next_speed() -> int:
	var at := GameSpeed.SPEEDS.find(_speed)
	return GameSpeed.SPEEDS[(at + 1) % GameSpeed.SPEEDS.size()]


## Shows the speed in use on the speed button, and marks Pause while paused (it then
## offers to resume).
func show_speed(speed: GameSpeed) -> void:
	_speed = speed.speed
	_pause.button_pressed = speed.paused
	_pause.icon = PLAY_ICON if speed.paused else PAUSE_ICON
	# a short caption, so the square stays 88 px wide and its row keeps its gaps
	_pause.text = "Play" if speed.paused else "Pause"
	_cycle.text = "%dx" % _speed


## Texts of the buttons that are marked: Pause while paused, else the speed.
func active_labels() -> Array[String]:
	var result: Array[String] = []
	result.append("Pause" if _pause.button_pressed else _cycle.text)
	return result


func _add_button(text: String, variation: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.theme_type_variation = variation
	button.custom_minimum_size = SQUARE
	add_child(button)
	return button
