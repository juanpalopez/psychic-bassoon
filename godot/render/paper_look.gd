## The papercraft look: the shaders and textures that the board and its props wear.
##
## A model from Blender names each material after the look it wants (`PK_CuttingMat`,
## `PK_Corrugated`, ...); props put their colours in the vertex colours on one `PK_PaperVC`
## surface, and the towers and units on one `PK_Craft` surface a part (`PK_Glass` for
## glass). `dress` swaps every imported surface material for its shader, and gives any other
## surface the plain paper shader in its imported colour (lit from inside when the model gave
## it an emission). Every look is one material shared by every mesh,
## so the board stays a handful of draw calls.
class_name PaperLook
extends RefCounted

const SHADERS := "res://render/paper/"
const NOISE := preload("res://assets/textures/paper/paper_noise.png")
const CUTS := preload("res://assets/textures/paper/mat_cuts.png")
## The shader that each Blender material name asks for (matched on the start of the name).
const LOOKS := {
	"PK_CuttingMat": "cutting_mat",
	"PK_Corrugated": "corrugated",
	"PK_Greyboard": "greyboard",
	"PK_PencilRing": "pencil_ring",
	"PK_DeskWood": "desk_wood",
	"PK_MaskingTape": "masking_tape",
	"PK_BlotInk": "blot_ink",
	"PK_PaperVC": "paper_vc",
	"PK_Craft": "craft_vc",
	"PK_Glass": "glass",
}
## The looks that draw the board's grid, and so need to know where the board is.
const GRID_LOOKS: Array[String] = ["cutting_mat", "masking_tape"]

static var _materials := {}
static var _dressed := {}


## The shared material for a look (a file name in `render/paper/` without `.gdshader`).
static func material(look: String) -> ShaderMaterial:
	if not _materials.has(look):
		var made := ShaderMaterial.new()
		made.shader = load(SHADERS + look + ".gdshader")
		made.set_shader_parameter("paper_noise", NOISE)
		if look == "cutting_mat":
			made.set_shader_parameter("cuts", CUTS)
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


## Tells the grid looks where the board's edges are: half its size in cells, x across and
## y in depth (the grid lines fall on whole numbers from the corner).
static func set_board(half_size: Vector2) -> void:
	for look in GRID_LOOKS:
		material(look).set_shader_parameter("board_half", half_size)


## A copy of `mesh` with each surface wearing its look, made once per mesh.
static func dress(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	if _dressed.has(mesh):
		return _dressed[mesh]
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		copy.surface_set_material(i, look_for(mesh.surface_get_material(i)))
	_dressed[mesh] = copy
	return copy


## The look for one imported material: its named shader, or plain paper in its colour.
static func look_for(imported: Material) -> Material:
	var material_name := imported.resource_name if imported != null else ""
	for prefix in LOOKS:
		if material_name.begins_with(prefix):
			return material(LOOKS[prefix])
	var colour := Color(0.8, 0.78, 0.72)
	var glow := 0.0
	if imported is BaseMaterial3D:
		var base := imported as BaseMaterial3D
		colour = base.albedo_color
		if base.emission_enabled:
			glow = clampf(base.emission_energy_multiplier * 0.4, 0.0, 1.5)
	return paper(colour, glow)
