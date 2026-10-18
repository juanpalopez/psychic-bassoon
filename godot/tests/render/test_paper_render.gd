## The painted paper as drawn: these render small scenes and read the pixels back, so they need
## a real renderer. The headless suite (CI) skips them; run them under a display:
##   xvfb-run -a godot --path godot --rendering-driver vulkan -s addons/gut/gut_cmdln.gd \
##     -gdir=res://tests -ginclude_subdirs -gselect=test_paper_render -gexit
## (add `--rendering-method mobile` for the phone renderer).
extends GutTest

const SIZE := Vector2i(96, 48)


func _can_render() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_video_adapter_name() != ""


## Renders `nodes` in a world of their own with no sky light, seen straight on from +z by an
## orthographic camera 4 m tall, and returns the picture.
func _render(nodes: Array[Node3D]) -> Image:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.BLACK
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0.0, 0.0, 5.0)
	viewport.add_child(camera)
	for node in nodes:
		viewport.add_child(node)
	add_child_autofree(viewport)
	await wait_frames(6)
	return viewport.get_texture().get_image()


## The mean colour of the left or right half of the picture (each half holds one quad).
func _half(image: Image, right: bool) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	var from := SIZE.x / 2 if right else 0
	for y in range(SIZE.y / 3, SIZE.y * 2 / 3):
		for x in range(from + SIZE.x / 6, from + SIZE.x / 3):
			sum += image.get_pixel(x, y)
			count += 1
	return sum / float(count)


func _quad(material: Material, x: float, uv2 := Vector2.ZERO) -> MeshInstance3D:
	var arrays := QuadMesh.new().get_mesh_arrays()
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var second := PackedVector2Array()
	second.resize(count)
	second.fill(uv2)
	arrays[Mesh.ARRAY_TEX_UV2] = second
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position.x = x
	return node


func _plain(look: String) -> ShaderMaterial:
	var made := PaperLook.material(look).duplicate() as ShaderMaterial
	made.set_shader_parameter("fibre", 0.0)
	made.set_shader_parameter("wash", 0.0)
	made.set_shader_parameter("edge_darken", 0.0)
	made.set_shader_parameter("ground_contact", 0.0)
	return made


func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.WHITE
	sun.light_energy = 0.6
	return sun


func test_a_hurt_foe_glows_dimmer() -> void:
	if not _can_render():
		pending("needs a renderer")
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = 2
	multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, 0.0)))
	multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)))
	multimesh.set_instance_color(0, Color.WHITE)
	multimesh.set_instance_color(1, Color(0.1, 0.1, 0.1))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = PaperLook.magic()
	var image: Image = await _render([node] as Array[Node3D])
	var healthy := _half(image, false)
	var hurt := _half(image, true)
	assert_gt(healthy.g, 0.3, "the magic glows with no light on it")
	assert_lt(hurt.g, healthy.g * 0.6, "the hurt one's glow is dimmed by its instance colour")


func test_a_baked_fold_darkens_the_paper() -> void:
	if not _can_render():
		pending("needs a renderer")
		return
	var look := _plain("painted")
	look.set_shader_parameter("contact_from", 0)
	look.set_shader_parameter("fold_from", 1)
	var image: Image = await _render(
		[_quad(look, -1.0), _quad(look, 1.0, Vector2(1.0, 0.0)), _sun()] as Array[Node3D]
	)
	var flat := _half(image, false)
	var folded := _half(image, true)
	assert_gt(flat.v, 0.2, "lit")
	assert_lt(folded.v, flat.v * 0.85, "UV2.x = 1 is a crease")


func test_only_the_sun_adds_its_warmth() -> void:
	if not _can_render():
		pending("needs a renderer")
		return
	var sunlit: Image = await _render([_quad(_plain("painted"), -1.0), _sun()] as Array[Node3D])
	var lamp := OmniLight3D.new()
	lamp.light_color = Color.WHITE
	lamp.omni_range = 20.0
	lamp.position = Vector3(-1.0, 0.0, 3.0)
	var lamplit: Image = await _render([_quad(_plain("painted"), -1.0), lamp] as Array[Node3D])
	var by_sun := _half(sunlit, false)
	var by_lamp := _half(lamplit, false)
	assert_lt(by_sun.b, by_sun.r * 0.96, "the sun is warmed")
	assert_almost_eq(by_lamp.r, by_lamp.b, 0.02, "a white lamp stays white")


func test_a_moving_model_keeps_its_paper() -> void:
	if not _can_render():
		pending("needs a renderer")
		return
	# the same quad twice, 1.375 m apart (33 pixels): on the model its paper (here the broad
	# wash, which a walking foe would carry across the world's) is the same on both, in the
	# world it is not
	var differences := {}
	for look in ["paper_prop", "paper_vc"]:
		var made := PaperLook.material(look).duplicate() as ShaderMaterial
		made.set_shader_parameter("wash", 0.5)
		made.set_shader_parameter("glow", 0.0)
		made.set_shader_parameter("ground_contact", 0.0)
		var left := _quad(made, -0.6875)
		var right := _quad(made, 0.6875)
		var image: Image = await _render([left, right, _sun()] as Array[Node3D])
		var total := 0.0
		var shift := 33
		for y in range(SIZE.y / 3, SIZE.y * 2 / 3):
			for x in range(SIZE.x / 2 - shift / 2 - 8, SIZE.x / 2 - shift / 2 + 8):
				total += absf(image.get_pixel(x, y).v - image.get_pixel(x + shift, y).v)
		differences[look] = total
	assert_gt(differences["paper_vc"], 1.0, "in the world the two differ: %s" % differences)
	assert_lt(differences["paper_prop"], differences["paper_vc"] * 0.2, "on the model they match")
