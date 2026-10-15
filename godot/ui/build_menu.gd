## A strip along the bottom with one button per tower: its name and what it costs. It opens for a
## free plot, greys out what the player cannot afford, and announces the choice;
## it does not touch the game (the scene turns the choice into a command).
class_name BuildMenu
extends PanelContainer

signal tower_chosen(tower: String)
## A tower button was hovered or held: show its card; the pointer left: clear it.
signal info_requested(tower: String)
signal info_cleared

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(172.0, 96.0)
## How long a press must last to count as a hold (a look, not a choice).
const HOLD_SECONDS := 0.4

## The plot the menu was opened for.
var cell := BoardSpace.NO_CELL

var _tower_buttons: Array[Button] = []
var _buttons := 0
var _hold_timer: Timer
var _held_id := ""
var _hold_fired := false


func _ready() -> void:
	visible = false
	# one row along the bottom, so the board above it stays in view
	var box := HBoxContainer.new()
	add_child(box)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_SECONDS
	_hold_timer.timeout.connect(hold_elapsed)
	add_child(_hold_timer)
	for id in TOWERS.TOWER_IDS:
		var button := Button.new()
		var def: Dictionary = TOWERS.DEFS[id]
		button.text = "%s\n%d" % [def.name, def.cost[0]]
		button.custom_minimum_size = BUTTON_SIZE
		# long names wrap inside the fixed width, so five towers fit in one row
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.theme_type_variation = &"StripButton"
		button.pressed.connect(_choose.bind(id))
		button.mouse_entered.connect(func() -> void: info_requested.emit(id))
		button.mouse_exited.connect(func() -> void: info_cleared.emit())
		button.button_down.connect(_start_hold.bind(id))
		button.button_up.connect(_stop_hold)
		box.add_child(button)
		_tower_buttons.append(button)


## The tower buttons, in the order of `TOWER_IDS`.
func tower_buttons() -> Array[Button]:
	return _tower_buttons


## Opens the menu for a socket, with the Buttons the player has now.
func open_for(plot: Vector2i, buttons: int) -> void:
	cell = plot
	set_buttons(buttons)
	visible = true


func close() -> void:
	visible = false


## Greys out the towers that cost more than `buttons`.
func set_buttons(buttons: int) -> void:
	_buttons = buttons
	for i in _tower_buttons.size():
		var cost: int = TOWERS.DEFS[TOWERS.TOWER_IDS[i]].cost[0]
		_tower_buttons[i].disabled = cost > _buttons


## A press that lasted long enough: show the card instead of choosing.
func hold_elapsed() -> void:
	if _held_id == "":
		return
	_hold_fired = true
	info_requested.emit(_held_id)


func _start_hold(id: String) -> void:
	_held_id = id
	_hold_fired = false
	if _hold_timer.is_inside_tree():
		_hold_timer.start()


func _stop_hold() -> void:
	_hold_timer.stop()
	_held_id = ""


func _choose(id: String) -> void:
	if _hold_fired:
		# the press was a look: keep the menu open and the card showing
		_hold_fired = false
		return
	info_cleared.emit()
	tower_chosen.emit(id)
	close()
