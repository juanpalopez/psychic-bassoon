## Phase 3 stub scene: proves the web export runs and measures it.
##
## It draws a dusk-lit ground, a camera tilted like the real game's, and 80
## animated instances in one MultiMesh (the budget case), with an overlay that
## shows the frame rate and the engine version. It has no game logic: the
## simulation arrives in Phase 4.
extends Node3D

const FOE_COUNT := 80
const CAMERA_PITCH_DEGREES := 55.0
const CAMERA_FOV_DEGREES := 35.0
const CAMERA_DISTANCE := 16.0
const LANE_LENGTH := 12.0
const LANE_COUNT := 8

var _multimesh: MultiMesh
var _label: Label
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_camera()
	_build_ground()
	_build_foes()
	_build_overlay()


func _process(delta: float) -> void:
	_time += delta
	_move_foes()
	_label.text = (
		"Scrapline stub  |  Godot %s  |  %d fps  |  %d foes"
		% [
			Engine.get_version_info().string,
			Engine.get_frames_per_second(),
			FOE_COUNT,
		]
	)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1220")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f82c0")
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffc98a")
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	add_child(sun)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV_DEGREES
	var pitch := deg_to_rad(CAMERA_PITCH_DEGREES)
	camera.position = Vector3(0.0, sin(pitch) * CAMERA_DISTANCE, cos(pitch) * CAMERA_DISTANCE)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	add_child(camera)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(LANE_LENGTH + 4.0, LANE_COUNT + 4.0)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2f6b45")
	ground.material_override = material
	add_child(ground)


func _build_foes() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.6, 0.5)
	_multimesh.mesh = box
	_multimesh.instance_count = FOE_COUNT
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b8693a")
	instance.material_override = material
	add_child(instance)


func _move_foes() -> void:
	for i in FOE_COUNT:
		var lane := i % LANE_COUNT
		var along := fposmod(_time * 1.2 + float(i) * 0.37, LANE_LENGTH) - LANE_LENGTH / 2.0
		var z := float(lane) - float(LANE_COUNT - 1) / 2.0
		var bob := sin(_time * 6.0 + float(i)) * 0.05
		_multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(along, 0.3 + bob, z)))


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)
	add_child(layer)
