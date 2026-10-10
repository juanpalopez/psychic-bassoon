## Player actions. They are the only way in: state changes through commands
## and ticks, nothing else.
## Treat a command as immutable once submitted: the queue and any rejection
## event keep a reference to it.
class_name Command
extends RefCounted

enum Kind { BUILD, UPGRADE, SELL, LAUNCH_WAVE }

var kind: Kind = Kind.LAUNCH_WAVE
## BUILD: a tower id from `content/towers.gd`.
var tower: String = ""
## BUILD: the plot cell.
var col: int = 0
var row: int = 0
## UPGRADE and SELL: the tower's id.
var tower_id: int = 0


static func build(tower_type: String, cell_col: int, cell_row: int) -> Command:
	var command := Command.new()
	command.kind = Kind.BUILD
	command.tower = tower_type
	command.col = cell_col
	command.row = cell_row
	return command


static func upgrade(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.UPGRADE
	command.tower_id = id
	return command


static func sell(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.SELL
	command.tower_id = id
	return command


static func launch_wave() -> Command:
	var command := Command.new()
	command.kind = Kind.LAUNCH_WAVE
	return command
