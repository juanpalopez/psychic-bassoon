## A preview of the diorama's road and scenery builders before the terrain (#324) lands: the
## map's terraces as stepped boxes (from `GameMap.height_at`, the river cells sunk into a gorge),
## the road beds and bridges on them, and a camera like the game's. It saves one screenshot.
##
##   SHOT=/tmp/shot.png VIEW=bridge SEED=1 xvfb-run -a -s "-screen 0 1280x720x24" godot \
##     --path godot --rendering-driver vulkan --resolution 1280x720 -s tools/diorama_preview.gd
##
## VIEW is `overview` (the default: the whole board), `bridge`, `join` (where the feeder meets
## the main road) or `heart` (the Heartstone's end). Add `--rendering-method mobile` for the
## phone renderer. Render-only: it reads the map and never changes the game.
extends SceneTree

## World height of one terrace, and the river's floor below the valley floor.
const TERRACE := 0.45
const GORGE := -0.9
## How far past the board the stepped ground carries on, in cells.
const MARGIN := 40
const COLOURS := {
	GameMap.Region.MEADOW: Color("6f8f3a"),
	GameMap.Region.FOREST: Color("4a6a2c"),
	GameMap.Region.ROCKS: Color("9b8b78"),
	GameMap.Region.DIRT: Color("a39a52"),
}
const RIVER_COLOUR := Color("7fc4f2")
const FRAMES := 60

var _frames := 0
var _map: GameMap
var _river := {}


func _init() -> void:
	var map_seed := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var game := Game.create(map_seed)
	_map = game.map
	for cell in _map.river:
		_river[cell] = true
	var world := Node3D.new()
	root.add_child(world)
	_add_light(world)
	world.add_child(_ground())
	var height := _height
	world.add_child(RoadBedBuilder.build(_map, game.routes, height))
	_add_heartstone(world)
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


## The terrain top at a cell: its terrace, the gorge under the river, and off the board the
## nearest edge cell's terrace (so the valley carries on).
func _height(cell: Vector2i) -> float:
	if _river.has(cell):
		return GORGE
	var inside := Vector2i(clampi(cell.x, 0, _map.cols - 1), clampi(cell.y, 0, _map.rows - 1))
	return float(_map.height_at(inside)) * TERRACE


func _ground() -> MultiMeshInstance3D:
	var cells: Array[Vector2i] = []
	for row in range(-MARGIN, _map.rows + MARGIN):
		for col in range(-MARGIN, _map.cols + MARGIN):
			cells.append(Vector2i(col, row))
	var box := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = cells.size()
	for i in cells.size():
		var cell := cells[i]
		var top := _height(cell)
		var bottom := GORGE - 1.0
		var at := BoardSpace.point_to_world(float(cell.x) + 0.5, float(cell.y) + 0.5)
		var basis := Basis.from_scale(Vector3(1.0, top - bottom, 1.0))
		multimesh.set_instance_transform(
			i, Transform3D(basis, at + Vector3(0, (top + bottom) / 2.0, 0))
		)
		var colour: Color = COLOURS[_map.region_at(cell)]
		if _river.has(cell):
			colour = RIVER_COLOUR
		elif not _map.in_bounds(cell):
			colour = colour.lerp(Color("a39a52"), 0.25)
		var shade := 0.94 + 0.06 * CellHash.of(cell.x, cell.y, 0, 7)
		multimesh.set_instance_color(i, Color(colour.r * shade, colour.g * shade, colour.b * shade))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	return node


func _add_heartstone(world: Node3D) -> void:
	var block := _map.heartstone
	var centre := Vector2(block.position) + Vector2(block.size) / 2.0
	var at := BoardSpace.point_to_world(centre.x, centre.y)
	var scene: PackedScene = load("res://assets/models/towers/heartstone.glb")
	var heart: Node3D = scene.instantiate() if scene != null else Node3D.new()
	heart.position = at + Vector3(0, _height(block.position) + 0.02, 0)
	heart.scale = Vector3.ONE * 0.8
	world.add_child(heart)


func _add_light(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c7bdb3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9cbe0")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.fog_enabled = true
	environment.fog_light_color = Color("c7bdb3")
	environment.fog_density = 0.0025
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -91.5, 0)
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	world.add_child(sun)


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
