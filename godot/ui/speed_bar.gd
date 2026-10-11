## Pause and the 1x, 2x, 3x buttons. It does not touch the game: it announces
## the choice and shows which one is active.
class_name SpeedBar
extends HBoxContainer

signal speed_chosen(speed: int)
signal pause_toggled

const BUTTON_SIZE := Vector2(96.0, 96.0)

var _buttons: Array[Button] = []


func _ready() -> void:
	_add_button("Pause").pressed.connect(func() -> void: pause_toggled.emit())
	for value in GameSpeed.SPEEDS:
		_add_button("%dx" % value).pressed.connect(func() -> void: speed_chosen.emit(value))


## Pause first, then one button per speed.
func buttons() -> Array[Button]:
	return _buttons


## Marks the active button: Pause while paused, else the chosen speed.
func show_speed(speed: GameSpeed) -> void:
	_buttons[0].button_pressed = speed.paused
	for i in GameSpeed.SPEEDS.size():
		_buttons[i + 1].button_pressed = not speed.paused and speed.speed == GameSpeed.SPEEDS[i]


## Texts of the buttons that are marked.
func active_labels() -> Array[String]:
	var result: Array[String] = []
	for button in _buttons:
		if button.button_pressed:
			result.append(button.text)
	return result


func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = BUTTON_SIZE
	add_child(button)
	_buttons.append(button)
	return button
