## The overlay for a lost game, with a Play again button. It does not touch the
## game: it announces the choice and the scene starts the new game.
class_name GameOverPanel
extends PanelContainer

signal play_again

const BUTTON_SIZE := Vector2(320.0, 96.0)

var _title := Label.new()
var _detail := Label.new()
var _play_again := Button.new()


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_title.text = "The kingdom has fallen"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_again.text = "Play again"
	_play_again.custom_minimum_size = BUTTON_SIZE
	_play_again.pressed.connect(func() -> void: play_again.emit())
	box.add_child(_title)
	box.add_child(_detail)
	box.add_child(_play_again)


## Opens the overlay for a game lost on `wave`.
func show_for(wave: int) -> void:
	_detail.text = "You fell on wave %d" % wave
	visible = true


func close() -> void:
	visible = false


func title_text() -> String:
	return _title.text


func detail_text() -> String:
	return _detail.text


func play_again_button() -> Button:
	return _play_again
