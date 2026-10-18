## The guards of the Guard Tents, drawn at their posts on the road: the papercraft guard
## (`assets/models/units/guard.glb`, a capsule when the file is missing) with a health bar
## over it, facing up the road towards the foes. Its stop-motion clips follow the game: it
## idles, strikes while it holds a foe, falls flat when it falls (and is hidden once the
## fall is over) and springs back up when it is raised again. One node per guard, kept
## between calls, so calling `update` every frame creates no nodes. Guards stand on the main
## route (`routes[0]`): the game has one route. It only reads the game.
class_name GuardsView
extends Node3D

const MODEL := "res://assets/models/units/guard.glb"
## Where the road surface is, so a guard stands on it (as the foes do).
## Feet stand on the lane.
const GROUND := Board.ROAD_HEIGHT
const BODY_RADIUS := 0.2
const BODY_HEIGHT := 0.9
const BAR_WIDTH := 0.5
const BAR_THICKNESS := 0.06
const BAR_GAP := 0.12
const BODY_COLOUR := Color("9c53c7")
const BAR_COLOUR := Color("7be07b")
## Seconds a fallen guard stays on the ground before it is hidden (the fall clip).
const FALL_SECONDS := 1.0
## How far up the road (cells) a guard looks to face the foes.
const LOOK_AHEAD := 0.5
const LOOPS: Array[String] = ["idle", "strike"]

var _nodes := {}
## guard id -> what it is doing: "idle", "strike", "fall" or "down".
var _state := {}
## guard id -> seconds left of its fall.
var _falling := {}


## Forgets every guard (a new game starts).
func reset() -> void:
	for node in _nodes.values():
		remove_child(node)
		node.queue_free()
	_nodes.clear()
	_state.clear()
	_falling.clear()


## Shows each guard of the game at its post, adds the new ones and drops the gone.
func update(game: GameState) -> void:
	var seen := {}
	for guard in game.guards:
		seen[guard.id] = true
		var node: Node3D = _nodes.get(guard.id)
		if node == null:
			node = _make()
			_nodes[guard.id] = node
			add_child(node)
			_state[guard.id] = "idle" if guard.alive else "down"
			_play(node, _state[guard.id])
		var route: Route = game.routes[0]
		var at := route.position_at(guard.post)
		var world := BoardSpace.point_to_world(at.x, at.y)
		node.position = Vector3(world.x, GROUND, world.z)
		var ahead := route.position_at(maxf(guard.post - LOOK_AHEAD, 0.0))
		var toward := BoardSpace.point_to_world(ahead.x, ahead.y) - world
		var turned := node.get_child(0) as Node3D
		if toward.length() > 1e-6:
			# the model turns; the root and its health bar stay square to the camera
			turned.rotation.y = atan2(toward.x, toward.z)
		_follow(guard, node)
		var bar := node.get_node("Bar") as Node3D
		bar.visible = guard.alive
		bar.scale.x = 0.0 if guard.max_hp <= 0.0 else clampf(guard.hp / guard.max_hp, 0.0, 1.0)
	for id in _nodes.keys():
		if not seen.has(id):
			var gone: Node = _nodes[id]
			_nodes.erase(id)
			_state.erase(id)
			_falling.erase(id)
			remove_child(gone)
			gone.queue_free()


## Moves the falls on by `delta` seconds: a guard whose fall is over is hidden.
func advance(delta: float) -> void:
	for id in _falling.keys():
		_falling[id] -= delta
		if _falling[id] <= 0.0:
			_falling.erase(id)
			_state[id] = "down"
			(_nodes[id] as Node3D).visible = false


func _process(delta: float) -> void:
	advance(delta)


func guard_count() -> int:
	return _nodes.size()


## Whether the guard is drawn (a fallen guard is drawn until its fall is over).
func is_shown(guard_id: int) -> bool:
	return (_nodes[guard_id] as Node3D).visible


func position_of(guard_id: int) -> Vector3:
	return (_nodes[guard_id] as Node3D).position


## What the guard is doing: "idle", "strike", "fall" or "down".
func state_of(guard_id: int) -> String:
	return _state[guard_id]


## The clip the guard's model is playing ("" for the capsule).
func clip_of(guard_id: int) -> String:
	var player := StopMotion.player_of(_nodes[guard_id])
	return player.current_animation if player != null else ""


## The bar's length as a share of the full bar.
func health_fraction_of(guard_id: int) -> float:
	return ((_nodes[guard_id] as Node3D).get_node("Bar") as Node3D).scale.x


## Turns the game's guard into a clip: strike while it holds a foe, idle otherwise; fall
## when it falls, rise when it is raised again.
func _follow(guard: Guard, node: Node3D) -> void:
	var was: String = _state[guard.id]
	var now := was
	if guard.alive:
		now = "strike" if guard.foe_id >= 0 else "idle"
		if was == "fall" or was == "down":
			_falling.erase(guard.id)
			node.visible = true
			_state[guard.id] = now
			_play(node, "rise")
			_queue(node, now)
			return
	elif was != "fall" and was != "down":
		now = "fall"
		_falling[guard.id] = FALL_SECONDS
	if now != was:
		_state[guard.id] = now
		_play(node, now)
	node.visible = guard.alive or _state[guard.id] == "fall"


func _play(node: Node3D, clip: String) -> void:
	var player := StopMotion.player_of(node)
	if player != null and player.has_animation(clip):
		player.clear_queue()
		player.play(clip)


func _queue(node: Node3D, clip: String) -> void:
	var player := StopMotion.player_of(node)
	if player != null and player.has_animation(clip):
		player.queue(clip)


func _make() -> Node3D:
	var root := Node3D.new()
	var packed := ModelLoader.scene(MODEL)
	var model := packed.instantiate() as Node3D if packed != null else null
	if model != null:
		model.name = "Model"
		StopMotion.dress(model)
		StopMotion.cast_shadows(model, "")
		root.add_child(model)
		var player := StopMotion.player_of(model)
		if player != null:
			StopMotion.prepare(player, LOOPS)
	else:
		# the fallback when the model file is missing
		var body := MeshInstance3D.new()
		body.name = "Model"
		var capsule := CapsuleMesh.new()
		capsule.radius = BODY_RADIUS
		capsule.height = BODY_HEIGHT
		body.mesh = capsule
		body.position.y = BODY_HEIGHT / 2.0
		body.material_override = _flat(BODY_COLOUR)
		root.add_child(body)
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var box := BoxMesh.new()
	box.size = Vector3(BAR_WIDTH, BAR_THICKNESS, BAR_THICKNESS)
	bar.mesh = box
	bar.material_override = _flat(BAR_COLOUR)
	bar.position.y = BODY_HEIGHT + BAR_GAP
	# square to the camera, which is turned about the vertical axis
	bar.rotation.y = deg_to_rad(CameraRig.YAW_DEGREES)
	root.add_child(bar)
	return root


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
