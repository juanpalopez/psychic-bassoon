## The top bar: Buttons, Heartstone health, wave and seed, one label each.
class_name TopBar
extends HBoxContainer

var _labels: Array[Label] = []


func _ready() -> void:
	for i in 4:
		var label := Label.new()
		add_child(label)
		_labels.append(label)


## Reads the game's numbers; call it whenever they may have changed.
func show_state(game: GameState) -> void:
	_labels[0].text = "Buttons %d" % game.buttons
	_labels[1].text = "Heartstone %d" % game.heartstone_health
	_labels[2].text = "Wave %d" % game.wave
	_labels[3].text = "Seed %d" % game.seed


## The text of each label, in order.
func texts() -> Array[String]:
	var result: Array[String] = []
	for label in _labels:
		result.append(label.text)
	return result
