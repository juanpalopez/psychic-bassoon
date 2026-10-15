## The stats chip: Buttons, Heartstone health and wave, one label each.
class_name TopBar
extends HBoxContainer

const RULES := preload("res://content/game_rules.gd")

var _labels: Array[Label] = []


func _ready() -> void:
	for i in 3:
		var label := Label.new()
		add_child(label)
		_labels.append(label)


## Reads the game's numbers; call it whenever they may have changed.
func show_state(game: GameState) -> void:
	_labels[0].text = "Buttons %d" % game.buttons
	_labels[1].text = "Heartstone %d" % game.heartstone_health
	_labels[2].text = "Wave %d/%d" % [game.wave, RULES.WIN_WAVE]


## The text of each label, in order.
func texts() -> Array[String]:
	var result: Array[String] = []
	for label in _labels:
		result.append(label.text)
	return result
