## A panel for a selected tower: name, level, stats, Upgrade and Sell. It does
## not touch the game; it announces the player's choice with the tower's id.
class_name TowerPanel
extends PanelContainer

signal upgrade_pressed(tower_id: int)
signal sell_pressed(tower_id: int)

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(240.0, 96.0)
const FONT_SIZE := 30

var _tower: Tower
var _buttons := 0
var _title := Label.new()
var _stats := Label.new()
var _upgrade := Button.new()
var _sell := Button.new()


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	for label in [_title, _stats]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		box.add_child(label)
	for button in [_upgrade, _sell]:
		button.custom_minimum_size = BUTTON_SIZE
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		box.add_child(button)
	_upgrade.pressed.connect(func() -> void: upgrade_pressed.emit(_tower.id))
	_sell.pressed.connect(func() -> void: sell_pressed.emit(_tower.id))


## Opens the panel for a tower, with the Buttons the player has now.
func show_tower(tower: Tower, buttons: int) -> void:
	_tower = tower
	_buttons = buttons
	refresh()
	visible = true


func close() -> void:
	visible = false


## The tower the panel is open for, or null.
func tower() -> Tower:
	return _tower if visible else null


## Updates what can be afforded without rebuilding the text.
func set_buttons(buttons: int) -> void:
	_buttons = buttons
	refresh()


## Re-reads the tower (it may have been upgraded) and the Buttons.
func refresh() -> void:
	if _tower == null:
		return
	var def: Dictionary = TOWERS.DEFS[_tower.type]
	var level := _tower.level
	_title.text = "%s  Level %d" % [def.name, level + 1]
	_stats.text = (
		"Damage %d  Range %s  Rate %s/s" % [def.damage[level], def.range[level], def.rate[level]]
	)
	var cost := TowerInfo.next_cost(_tower)
	if cost < 0:
		_upgrade.text = "Max level"
		_upgrade.disabled = true
	else:
		_upgrade.text = "Upgrade  %d" % cost
		_upgrade.disabled = cost > _buttons
	_sell.text = "Sell  +%d" % TowerInfo.refund(_tower)


func title_text() -> String:
	return _title.text


func stats_text() -> String:
	return _stats.text


func upgrade_button() -> Button:
	return _upgrade


func sell_button() -> Button:
	return _sell
