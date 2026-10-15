## Remembers that the tour was shown. Two functions stand in for the storage so a test can
## use a dictionary; `default` stores in the browser (localStorage) or a file.
class_name TourProgress
extends RefCounted

const KEY := "papercraft_tour_seen"
const FILE := "user://progress.cfg"

var _read: Callable
var _write: Callable


func _init(read: Callable, write: Callable) -> void:
	_read = read
	_write = write


## Whether the tour should open on start: not if it was seen, not when the page says
## `?tour=0` (the browser smoke test) and not in a headless run (the unit tests).
static func wanted(was_seen: bool, tour_param: String, headless: bool) -> bool:
	return not was_seen and tour_param != "0" and not headless


## The storage the game uses: localStorage on the web, a config file elsewhere.
static func default() -> TourProgress:
	if OS.has_feature("web"):
		return TourProgress.new(
			func() -> bool:
				return str(JavaScriptBridge.eval("localStorage.getItem('%s')" % KEY)) == "1",
			func() -> void: JavaScriptBridge.eval("localStorage.setItem('%s', '1')" % KEY)
		)
	return TourProgress.new(
		func() -> bool:
			var file := ConfigFile.new()
			return file.load(FILE) == OK and bool(file.get_value("tour", "seen", false)),
		func() -> void:
			var file := ConfigFile.new()
			file.load(FILE)
			file.set_value("tour", "seen", true)
			file.save(FILE)
	)


func seen() -> bool:
	return _read.call()


func mark_seen() -> void:
	_write.call()
