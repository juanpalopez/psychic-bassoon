## Remembers that the intro wave was shown (the key and the `?tour=` parameter keep the old
## name so browsers that saw the card tour stay seen). Two functions stand in for the storage
## so a test can use a dictionary; `default` stores in the browser (localStorage) or a file.
class_name IntroProgress
extends RefCounted

const KEY := "papercraft_tour_seen"
const FILE := "user://progress.cfg"

var _read: Callable
var _write: Callable
# a browser that refuses to store (private mode) still stops asking in the same session
var _seen_now := false


func _init(read: Callable, write: Callable) -> void:
	_read = read
	_write = write


## Whether the intro wave should open on start: not if it was seen, not when the page says
## `?tour=0` (the browser smoke test) and not in a headless run (the unit tests).
static func wanted(was_seen: bool, tour_param: String, headless: bool) -> bool:
	return not was_seen and tour_param != "0" and not headless


## The storage the game uses: localStorage on the web, a config file elsewhere.
static func default() -> IntroProgress:
	if OS.has_feature("web"):
		return IntroProgress.new(
			func() -> bool:
				return str(JavaScriptBridge.eval("localStorage.getItem('%s')" % KEY)) == "1",
			func() -> void: JavaScriptBridge.eval("localStorage.setItem('%s', '1')" % KEY)
		)
	return IntroProgress.new(
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
	return _seen_now or _read.call()


func mark_seen() -> void:
	_seen_now = true
	_write.call()
