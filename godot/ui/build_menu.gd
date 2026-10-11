## A panel with one button per tower: its name and what it costs. It opens for a
## free plot, greys out what the player cannot afford, and announces the choice;
## it does not touch the game (the scene turns the choice into a command).
class_name BuildMenu
extends PanelContainer

signal tower_chosen(tower: String)

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(240.0, 96.0)
const FONT_SIZE := 30

## The plot the menu was opened for.
var cell := BoardSpace.NO_CELL

var _buttons: Array[Button] = []
var _gold := 0


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	for id in TOWERS.TOWER_IDS:
		var button := Button.new()
		var def: Dictionary = TOWERS.DEFS[id]
		button.text = "%s  %d" % [def.name, def.cost[0]]
		button.custom_minimum_size = BUTTON_SIZE
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(_choose.bind(id))
		box.add_child(button)
		_buttons.append(button)


## The tower buttons, in the order of `TOWER_IDS`.
func buttons() -> Array[Button]:
	return _buttons


## Opens the menu for a plot, with the gold the player has now.
func open_for(plot: Vector2i, gold: int) -> void:
	cell = plot
	set_gold(gold)
	visible = true


func close() -> void:
	visible = false


## Greys out the towers that cost more than `gold`.
func set_gold(gold: int) -> void:
	_gold = gold
	for i in _buttons.size():
		var cost: int = TOWERS.DEFS[TOWERS.TOWER_IDS[i]].cost[0]
		_buttons[i].disabled = cost > _gold


func _choose(id: String) -> void:
	tower_chosen.emit(id)
	close()
