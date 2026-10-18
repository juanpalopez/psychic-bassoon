## The painted paper (Hand-Folded Fantasy): every lit look shares one painted light, the
## models' materials map onto it (the glowing ones onto the cool magic), and the colours stay
## in the shaders, not in the script.
extends GutTest

const INCLUDE := '#include "res://render/paper/painted.gdshaderinc"'
## The looks allowed their own light: wet ink and glass may shine (STYLE.md: only water and
## magic shine), and the unshaded beam and bars have no light at all.
const OWN_LIGHT: Array[String] = ["blot_ink", "glass", "prism_beam", "foe_bar"]


func _code(look: String) -> String:
	return PaperLook.material(look).shader.code


func _imported(colour: Color, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = colour
	if glow != Color.BLACK:
		made.emission_enabled = true
		made.emission = glow
	return made


func test_every_lit_look_wears_the_painted_light() -> void:
	var looks: Array[String] = []
	for file in DirAccess.get_files_at(PaperLook.SHADERS):
		if file.ends_with(".gdshader"):
			looks.append(file.get_basename())
	assert_gt(looks.size(), 10, "found the looks")
	for look in looks:
		if look in OWN_LIGHT:
			continue
		var code := _code(look)
		assert_true(code.contains(INCLUDE), "%s includes the painted light" % look)
		assert_false(code.contains("void light()"), "%s keeps no light of its own" % look)
		assert_false(code.contains("SPECULAR ="), "%s stays matte" % look)


func test_the_painted_light_is_matte_and_has_no_hard_bands() -> void:
	var code := (load(PaperLook.SHADERS + "painted.gdshaderinc") as ShaderInclude).code
	assert_true(code.contains("void light()"))
	assert_false(code.contains("SPECULAR_LIGHT"), "no specular from the lights")
	assert_true(code.contains("SPECULAR = 0.0"), "no reflections")
	assert_true(code.contains("ROUGHNESS = 1.0"))
	var steps := RegEx.create_from_string("(?<![a-z_])(step|floor|round)\\(")
	assert_null(steps.search(code), "no cel steps")


func test_the_painted_colours_are_shader_uniforms_with_the_style_palette() -> void:
	var code := (load(PaperLook.SHADERS + "painted.gdshaderinc") as ShaderInclude).code
	# sun #ffd9a8, sky #b9cbe0, soil lip deep shade #3e2b1c (docs/art/STYLE.md)
	for uniform in [
		"light_warm : source_color = vec3(1.0, 0.851, 0.659)",
		"shade_cool : source_color = vec3(0.725, 0.796, 0.878)",
		"fold_colour : source_color = vec3(0.243, 0.169, 0.11)",
	]:
		assert_true(code.contains("uniform vec3 " + uniform), uniform)


func test_the_look_script_holds_no_colour_of_its_own() -> void:
	var source := (load("res://render/paper_look.gd") as GDScript).source_code
	assert_false(source.contains("Color("), "colours live in the shaders")


func test_a_named_material_gets_its_look() -> void:
	var imported := StandardMaterial3D.new()
	imported.resource_name = "PK_Painted.001"
	assert_eq(PaperLook.look_for(imported), PaperLook.material("painted"))
	imported.resource_name = "PK_Magic"
	assert_eq(PaperLook.look_for(imported), PaperLook.material("painted_magic"))


func test_a_plain_material_becomes_painted_paper_in_its_colour() -> void:
	var look := PaperLook.look_for(_imported(Color("6f8f3a"))) as ShaderMaterial
	assert_eq(look.shader, PaperLook.material("paper_prop").shader)
	assert_eq(look.get_shader_parameter("colour"), Color("6f8f3a"))
	assert_eq(PaperLook.look_for(_imported(Color("6f8f3a"))), look, "shared, not one per mesh")


func test_a_glowing_material_becomes_magic_in_its_glow_colour() -> void:
	var look := PaperLook.look_for(_imported(Color("9e38f2"), Color("a63bff"))) as ShaderMaterial
	assert_eq(look.shader, PaperLook.material("painted_magic").shader)
	assert_eq(look.get_shader_parameter("magic"), Color("a63bff"))
	assert_eq(look.get_shader_parameter("tint"), Color("9e38f2"))


func test_no_material_gets_the_plain_paper_of_the_shader() -> void:
	assert_eq(PaperLook.look_for(null), PaperLook.material("paper_prop"))


func test_the_magic_default_keeps_the_shader_colours() -> void:
	var look := PaperLook.magic()
	assert_eq(look.shader, PaperLook.material("painted_magic").shader)
	assert_null(look.get_shader_parameter("magic"), "the shader's cool cyan")
	assert_eq(PaperLook.magic(), look, "shared")


func test_the_generic_painted_shader_takes_vertex_colour_a_map_and_baked_contact() -> void:
	var code := _code("painted")
	for part in ["albedo_map", "COLOR.rgb", "contact_from", "COLOR.a", "contact_map", "UV2"]:
		assert_true(code.contains(part), part)
