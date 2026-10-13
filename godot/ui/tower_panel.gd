## A panel for a selected tower: name, level, stats, Upgrade and Sell. It does
## not touch the game; it announces the player's choice with the tower's id.
class_name TowerPanel
extends PanelContainer

signal upgrade_pressed(tower_id: int)
signal sell_pressed(tower_id: int)

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(240.0, 96.0)

var _tower: Tower
var _buttons := 0
## Range to show in cells, or -1 for the level's base range.
var _reach := -1.0
var _title := Label.new()
var _stats := Label.new()
var _upgrade := Button.new()
var _sell := Button.new()


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	for label in [_title, _stats]:
		box.add_child(label)
	for button in [_upgrade, _sell]:
		button.custom_minimum_size = BUTTON_SIZE
		box.add_child(button)
	_upgrade.pressed.connect(func() -> void: upgrade_pressed.emit(_tower.id))
	_sell.pressed.connect(func() -> void: sell_pressed.emit(_tower.id))


## Opens the panel for a tower, with the Buttons the player has now and the
## range it really reaches (its cell's elevation bonus included).
func show_tower(tower: Tower, buttons: int, reach: float = -1.0) -> void:
	_tower = tower
	_buttons = buttons
	_reach = reach
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


## Sets the range shown, in cells.
func set_reach(reach: float) -> void:
	_reach = reach
	refresh()


## Re-reads the tower (it may have been upgraded) and the Buttons.
func refresh() -> void:
	if _tower == null:
		return
	var def: Dictionary = TOWERS.DEFS[_tower.type]
	var level := _tower.level
	_title.text = "%s  Level %d" % [def.name, level + 1]
	var reach: float = def.range[level] if _reach < 0.0 else _reach
	if def.get("support", false):
		_stats.text = (
			"Guards +%d%% speed  +%d hp/s  Reach %.1f"
			% [
				int(round(def.guard_speed_bonus[level] * 100.0)),
				int(round(def.guard_regen_bonus[level])),
				reach
			]
		)
	elif def.get("guards", false):
		_stats.text = (
			"Guards %d hp  Blow %d  Reach %.1f"
			% [def.guard_hp[level], def.guard_damage[level], reach]
		)
	elif def.get("beam", false):
		_stats.text = "Damage %d/s  Range %s" % [def.damage[level], reach]
	else:
		_stats.text = (
			"Damage %d  Range %s  Rate %s/s" % [def.damage[level], reach, def.rate[level]]
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
