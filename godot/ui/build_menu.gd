## A panel with one button per tower, two to a row: its name and what it costs. It opens for a
## free plot, greys out what the player cannot afford, and announces the choice;
## it does not touch the game (the scene turns the choice into a command).
class_name BuildMenu
extends PanelContainer

signal tower_chosen(tower: String)

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(240.0, 96.0)

## The plot the menu was opened for.
var cell := BoardSpace.NO_CELL

var _tower_buttons: Array[Button] = []
var _buttons := 0


func _ready() -> void:
	visible = false
	# two columns: five towers in one would reach the speed bar on a phone
	var box := GridContainer.new()
	box.columns = 2
	add_child(box)
	for id in TOWERS.TOWER_IDS:
		var button := Button.new()
		var def: Dictionary = TOWERS.DEFS[id]
		button.text = "%s  %d" % [def.name, def.cost[0]]
		button.custom_minimum_size = BUTTON_SIZE
		button.pressed.connect(_choose.bind(id))
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


func _choose(id: String) -> void:
	tower_chosen.emit(id)
	close()
