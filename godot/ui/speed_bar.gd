## Pause, and one button that cycles the speed 1x, 2x, 3x. It does not touch the game: it
## announces the choice and shows which speed is active.
class_name SpeedBar
extends HBoxContainer

signal speed_chosen(speed: int)
signal pause_toggled

const PAUSE_SIZE := Vector2(110.0, 96.0)
const SPEED_SIZE := Vector2(96.0, 96.0)

var _pause: Button
var _cycle: Button
var _speed := GameSpeed.SPEEDS[0]


func _ready() -> void:
	_pause = _add_button("Pause", PAUSE_SIZE)
	_pause.pressed.connect(func() -> void: pause_toggled.emit())
	_cycle = _add_button("%dx" % _speed, SPEED_SIZE)
	_cycle.toggle_mode = false
	_cycle.pressed.connect(func() -> void: speed_chosen.emit(next_speed()))


## Pause first, then the speed button.
func buttons() -> Array[Button]:
	return [_pause, _cycle]


## The speed a press of the speed button would choose: the one after the shown speed,
## back to the first after the last.
func next_speed() -> int:
	var at := GameSpeed.SPEEDS.find(_speed)
	return GameSpeed.SPEEDS[(at + 1) % GameSpeed.SPEEDS.size()]


## Shows the speed in use on the speed button, and marks Pause while paused.
func show_speed(speed: GameSpeed) -> void:
	_speed = speed.speed
	_pause.button_pressed = speed.paused
	_cycle.text = "%dx" % _speed


## Texts of the buttons that are marked: Pause while paused, else the speed.
func active_labels() -> Array[String]:
	var result: Array[String] = []
	result.append("Pause" if _pause.button_pressed else _cycle.text)
	return result


func _add_button(text: String, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = size
	add_child(button)
	return button
