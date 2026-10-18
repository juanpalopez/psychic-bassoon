## The papercraft look: the shaders and textures that the board, its props, the towers and the
## foes wear.
##
## Every lit look is the painted paper of `render/paper/painted.gdshaderinc` (Hand-Folded
## Fantasy, `docs/art/STYLE.md`): warm where the sun hits, cool where it does not, matte, with
## fibre, folds and contact shading. A model from Blender names each material after the look it
## wants (`PK_Painted` for vertex-colour paper with contact baked in its alpha, `PK_Magic` for
## the cool glow, `PK_PencilRing`, ...); props put their colours in the vertex colours on one
## `PK_PaperVC` surface, and the towers and units on one `PK_Craft` surface a part (`PK_Glass`
## for glass). `dress` swaps every imported surface material for its shader, and gives any
## other surface the plain painted paper in its imported colour, or the magic glow in its
## emission colour when the model gave it one. Every look is one material shared by every
## mesh, so the board stays a handful of draw calls. The colours are the shaders' uniforms;
## this script only passes on what a model asked for.
class_name PaperLook
extends RefCounted

const SHADERS := "res://render/paper/"
const NOISE := preload("res://assets/textures/paper/paper_noise.png")
## The shader that each Blender material name asks for (matched on the start of the name).
const LOOKS := {
	"PK_PencilRing": "pencil_ring",
	"PK_BlotInk": "blot_ink",
	"PK_PaperVC": "paper_vc",
	"PK_Craft": "craft_vc",
	"PK_Glass": "glass",
	"PK_Painted": "painted",
	"PK_Magic": "painted_magic",
}

static var _materials := {}
static var _dressed := {}


## The shared material for a look (a file name in `render/paper/` without `.gdshader`).
static func material(look: String) -> ShaderMaterial:
	if not _materials.has(look):
		var made := ShaderMaterial.new()
		made.shader = load(SHADERS + look + ".gdshader")
		made.set_shader_parameter("paper_noise", NOISE)
		_materials[look] = made
	return _materials[look]


## The shared plain paper material in `colour`; `glow` above 0 lights it from inside.
static func paper(colour: Color, glow: float = 0.0) -> ShaderMaterial:
	var key := "paper %s %.2f" % [colour.to_html(false), glow]
	if not _materials.has(key):
		var made := material("paper_prop").duplicate() as ShaderMaterial
		made.set_shader_parameter("colour", colour)
		made.set_shader_parameter("glow", glow)
		_materials[key] = made
	return _materials[key]


## The shared magic material: paper in `paper_colour` glowing in `glow_colour` (either one
## left null keeps the shader's own: white paper and its cool cyan).
static func magic(glow_colour: Variant = null, paper_colour: Variant = null) -> ShaderMaterial:
	var key := "magic %s %s" % [_html(glow_colour), _html(paper_colour)]
	if not _materials.has(key):
		var made := material("painted_magic").duplicate() as ShaderMaterial
		if glow_colour is Color:
			made.set_shader_parameter("magic", glow_colour)
		if paper_colour is Color:
			made.set_shader_parameter("tint", paper_colour)
		_materials[key] = made
	return _materials[key]


static func _html(colour: Variant) -> String:
	return (colour as Color).to_html(false) if colour is Color else "-"


## A copy of `mesh` with each surface wearing its look, made once per mesh. A model that
## hovers (`grounded` false: the Razor Moth) gets its looks without the darkening at the foot.
static func dress(mesh: Mesh, grounded: bool = true) -> Mesh:
	if mesh == null:
		return null
	var key := [mesh, grounded]
	if _dressed.has(key):
		return _dressed[key]
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		copy.surface_set_material(i, look_for(mesh.surface_get_material(i), grounded))
	_dressed[key] = copy
	return copy


## The look for one imported material: its named shader, the magic glow in its emission
## colour when it glows, or plain paper in its colour (the shader's own when it has none);
## without the foot darkening when it is not `grounded`.
static func look_for(imported: Material, grounded: bool = true) -> Material:
	var look := _look_for(imported)
	return look if grounded else hovering(look)


## The shared copy of a look with no darkening at the foot, for a model that hovers.
static func hovering(look: Material) -> Material:
	if not look is ShaderMaterial:
		return look
	var key := "hovering %d" % look.get_instance_id()
	if not _materials.has(key):
		var made := look.duplicate() as ShaderMaterial
		made.set_shader_parameter("ground_contact", 0.0)
		_materials[key] = made
	return _materials[key]


static func _look_for(imported: Material) -> Material:
	var material_name := imported.resource_name if imported != null else ""
	for prefix in LOOKS:
		if material_name.begins_with(prefix):
			return material(LOOKS[prefix])
	if not imported is BaseMaterial3D:
		return material("paper_prop")
	var base := imported as BaseMaterial3D
	if base.emission_enabled:
		return magic(base.emission, base.albedo_color)
	return paper(base.albedo_color)
