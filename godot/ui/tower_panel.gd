## A panel for a selected tower: name, level, stats, Upgrade and Sell. It does
## not touch the game; it announces the player's choice with the tower's id.
class_name TowerPanel
extends PanelContainer

signal upgrade_pressed(tower_id: int)
signal sell_pressed(tower_id: int)
signal spec_pressed(tower_id: int, spec_id: String)
signal ability_pressed(tower_id: int)

const TOWERS := preload("res://content/towers.gd")
const SPECS := preload("res://content/specs.gd")
const BUTTON_SIZE := Vector2(190.0, 88.0)
const COIN := preload("res://assets/icons/coin.svg")

var _tower: Tower
var _buttons := 0
## Range to show in cells, or -1 for the level's base range.
var _reach := -1.0
var _title := Label.new()
var _stats := Label.new()
var _upgrade := Button.new()
var _sell := Button.new()
## Level 3 with no spec yet: one button per spec to choose from.
var _specs := HBoxContainer.new()
var _spec_buttons: Array[Button] = []
## With a spec chosen: the active ability, with its cooldown.
var _ability := Button.new()


func _ready() -> void:
	visible = false
	# a strip along the bottom: the words on the left, the two buttons beside them
	var row := HBoxContainer.new()
	add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_title.theme_type_variation = &"Title"
	_stats.theme_type_variation = &"Caption"
	for label in [_title, _stats]:
		words.add_child(label)
	_upgrade.theme_type_variation = &"ActionButton"
	_ability.theme_type_variation = &"ActionButton"
	_upgrade.icon = COIN
	_upgrade.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_upgrade)
	row.add_child(_specs)
	row.add_child(_ability)
	row.add_child(_sell)
	for button in [_upgrade, _sell, _ability]:
		button.custom_minimum_size = BUTTON_SIZE
	_ability.pressed.connect(func() -> void: ability_pressed.emit(_tower.id))
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
	var specs := SPECS.for_tower(_tower.type)
	var cost := TowerInfo.next_cost(_tower)
	var choosing := cost < 0 and _tower.spec == "" and not specs.is_empty()
	var chosen := _tower.spec != ""
	_upgrade.visible = not choosing and not chosen
	_specs.visible = choosing
	_ability.visible = chosen
	if cost < 0:
		_upgrade.text = "Max level"
		_upgrade.disabled = true
	else:
		_upgrade.text = "Upgrade %d" % cost
		_upgrade.disabled = cost > _buttons
	if choosing:
		_show_specs(specs)
	if chosen:
		var spec := SPECS.find(_tower.type, _tower.spec)
		# on the stats line: a longer title would widen the strip over Start wave
		_stats.text += "\n" + spec.name
		_ability.text = "%s\n%s" % [spec.active.name, _cooldown_text(_tower.ability_cooldown)]
		_ability.disabled = _tower.ability_cooldown > 0.0
	_sell.text = "Sell +%d" % TowerInfo.refund(_tower)


func title_text() -> String:
	return _title.text


func stats_text() -> String:
	return _stats.text


func upgrade_button() -> Button:
	return _upgrade


func sell_button() -> Button:
	return _sell


func spec_buttons() -> Array[Button]:
	return _spec_buttons


func ability_button() -> Button:
	return _ability


static func _cooldown_text(seconds: float) -> String:
	return "Ready" if seconds <= 0.0 else "%d s" % int(ceil(seconds))


## One button per spec, named with its cost; made on first use and reused.
func _show_specs(specs: Array) -> void:
	while _spec_buttons.size() < specs.size():
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.theme_type_variation = &"ActionButton"
		var index := _spec_buttons.size()
		button.pressed.connect(
			func() -> void: spec_pressed.emit(_tower.id, SPECS.for_tower(_tower.type)[index].id)
		)
		_specs.add_child(button)
		_spec_buttons.append(button)
	for i in _spec_buttons.size():
		var button := _spec_buttons[i]
		button.visible = i < specs.size()
		if i < specs.size():
			button.text = "%s\n%d" % [specs[i].name, specs[i].cost]
			button.disabled = int(specs[i].cost) > _buttons
