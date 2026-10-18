## A preview of the diorama (#324) with the road beds and bridges (#325) and the scatter (#326)
## plugged in: the game's `Board` for a seed, under the `main.tscn` sky and sun, seen from a camera
## like the game's, with no HUD. It saves one screenshot and prints the frame's draw calls and
## triangles.
##
##   SHOT=/tmp/shot.png VIEW=bridge SEED=1 xvfb-run -a -s "-screen 0 1280x720x24" godot \
##     --path godot --rendering-driver vulkan --resolution 1280x720 -s tools/diorama_preview.gd
##
## VIEW is `overview` (the default: the zoomed-out view of the game), `bridge`, `join` (where
## the feeder meets the main road) or `heart` (the Heartstone's end). Add
## `--rendering-method mobile` for the phone renderer, and SCENERY=0 or ROAD=0 to leave that
## slot empty. Render-only: it reads the map and never changes the game.
extends SceneTree

const FRAMES := 60

var _frames := 0
var _map: GameMap


func _init() -> void:
	var map_seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var game := Game.create(map_seed)
	_map = game.map
	var world := Node3D.new()
	root.add_child(world)
	_add_light(world)
	var board := Board.new()
	board.map_seed = map_seed
	world.add_child(board)
	board.show_map(game.map, game.routes)
	for slot: String in ["RoadBeds", "Scatter"]:
		var key := "ROAD" if slot == "RoadBeds" else "SCENERY"
		if OS.get_environment(key) == "0":
			board.diorama.use_builder(slot, DioramaBuilder.new())
	_add_camera(world, game, OS.get_environment("VIEW"))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == FRAMES:
		var image := root.get_viewport().get_texture().get_image()
		var path := OS.get_environment("SHOT")
		image.save_png(path if path != "" else "user://diorama_preview.png")
		print("saved ", image.get_size(), " ", RenderingServer.get_video_adapter_name())
		_print_counts()
		quit()
	return false


## The draw calls, triangles and objects of the last frame, in view and in the shadow pass.
func _print_counts() -> void:
	var viewport := root.get_viewport_rid()
	for pass_name: String in ["visible", "shadow"]:
		var kind := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
		if pass_name == "shadow":
			kind = RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
		var counts: Array[int] = []
		for info: int in [
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME,
			RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME,
		]:
			counts.append(RenderingServer.viewport_get_render_info(viewport, kind, info))
		print(
			(
				"%s: draw calls %d, triangles %d, objects %d"
				% [pass_name, counts[0], counts[1], counts[2]]
			)
		)


## The game's own sky and sun, taken from `main.tscn` (the rest of the scene is left out).
func _add_light(world: Node3D) -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	for node_name: String in ["WorldEnvironment", "Sun"]:
		var node := main.get_node(node_name)
		main.remove_child(node)
		node.owner = null
		world.add_child(node)
	main.free()


func _add_camera(world: Node3D, game: GameState, view: String) -> void:
	var target := Vector2(_map.cols, _map.rows) / 2.0
	var distance := 95.0
	var pitch := 62.0
	if view == "bridge" and not _map.bridges.is_empty():
		target = Vector2(_map.bridges[0].cell) + Vector2(0.5, 0.5)
		distance = 16.0
		pitch = 56.0
	elif view == "join" and game.routes.size() > 1:
		var lines := RoadBedBuilder.centrelines(game.routes)
		target = lines[1][lines[1].size() - 1]
		distance = 16.0
		pitch = 56.0
	elif view == "heart":
		target = Vector2(_map.heartstone.position) + Vector2(_map.heartstone.size) / 2.0
		distance = 16.0
		pitch = 56.0
	var camera := Camera3D.new()
	camera.fov = 20.0
	camera.far = 400.0
	world.add_child(camera)
	var focus := BoardSpace.point_to_world(target.x, target.y)
	var back := Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(0, 0, 1)
	var up := deg_to_rad(pitch)
	var offset := (back * cos(up) + Vector3.UP * sin(up)) * distance
	camera.look_at_from_position(focus + offset, focus, Vector3.UP)
