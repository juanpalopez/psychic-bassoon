## The health bars over the foes: one MultiMesh for all of them (a dark back and a coloured
## fill per bar, two instances of one camera-facing quad), so every bar costs one draw call.
##
## A bar shows only for a hurt, living foe; a full-hp foe has none (the board stays clear).
## The rules (when to show, width, colour) are static functions so a test can read them.
class_name FoeBars
extends MultiMeshInstance3D

const SHADER := preload("res://render/paper/foe_bar.gdshader")
## Bars drawn at most; more foes than this get none.
const MAX_BARS := 160
## A bar's size in cells (width, height), for a foe and for a boss.
const FOE_SIZE := Vector2(0.7, 0.1)
const BOSS_SIZE := Vector2(1.5, 0.18)
const BOSS_TYPES: Array[String] = ["cardboardGolem"]
## How far above a foe's head the bar's centre floats, in cells.
const LIFT := 0.2
## The fill is a little smaller than the back, so the back reads as a border (cells).
const BORDER := 0.03
## How far towards the camera the fill sits, so it is not hidden by the back.
const FILL_NEAR := 0.03
const BACK_COLOUR := Board.DESK_COLOUR
const FULL_COLOUR := GuardsView.BAR_COLOUR
const LOW_COLOUR := Board.SPAWN_COLOUR

var _bars := 0
# what was last written, kept so a headless test can read it back
var _positions: Array[Vector3] = []
var _fill_widths: Array[float] = []


func _init() -> void:
	name = "HealthBars"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = MAX_BARS * 2
	multimesh.visible_instance_count = 0
	# a bar must not be culled by the unit quad's box when the foe is at the screen edge
	custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 40, 200))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Whether a foe shows a bar: alive and hurt (not at full hp, not already dead).
static func is_shown(hp: float, max_hp: float, alive: bool) -> bool:
	return alive and max_hp > 0.0 and hp > 0.0 and hp < max_hp


## The share of health left, 0 to 1.
static func share(hp: float, max_hp: float) -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(hp / max_hp, 0.0, 1.0)


## The width of the fill for a health share on a bar `full_width` wide.
static func fill_width(health_share: float, full_width: float) -> float:
	return full_width * clampf(health_share, 0.0, 1.0)


## The bar's size in cells; a boss gets a larger one.
static func bar_size(type: String) -> Vector2:
	return BOSS_SIZE if BOSS_TYPES.has(type) else FOE_SIZE


## The fill colour: full green at full health, running to red as it falls.
static func fill_colour(health_share: float) -> Color:
	if health_share >= 1.0:
		return FULL_COLOUR
	return LOW_COLOUR.lerp(FULL_COLOUR, maxf(health_share, 0.0))


## Starts a frame: forgets last frame's bars.
func begin() -> void:
	_bars = 0
	_positions.clear()
	_fill_widths.clear()


## Adds a bar over a foe whose head is at `head` (world), `health_share` of its health left.
func add(head: Vector3, health_share: float, type: String) -> void:
	if _bars >= MAX_BARS:
		return
	var size := bar_size(type)
	var at := head + Vector3(0.0, LIFT + size.y / 2.0, 0.0)
	var inner := size.x - 2.0 * BORDER
	var width := fill_width(health_share, inner)
	var back := _bars * 2
	multimesh.set_instance_transform(
		back, Transform3D(Basis.from_scale(Vector3(size.x, size.y, 1.0)), at)
	)
	multimesh.set_instance_color(back, BACK_COLOUR)
	multimesh.set_instance_custom_data(back, Color(0.0, 0.0, 0.0, 0.0))
	var fill_height := maxf(size.y - 2.0 * BORDER, 0.01)
	multimesh.set_instance_transform(
		back + 1, Transform3D(Basis.from_scale(Vector3(maxf(width, 0.0001), fill_height, 1.0)), at)
	)
	multimesh.set_instance_color(back + 1, fill_colour(health_share))
	# slide the fill so its left edge stays on the bar's left edge
	multimesh.set_instance_custom_data(back + 1, Color(-(inner - width) / 2.0, FILL_NEAR, 0.0, 0.0))
	_positions.append(at)
	_fill_widths.append(width)
	_bars += 1


## Ends a frame: draws the bars added since `begin`.
func finish() -> void:
	multimesh.visible_instance_count = _bars * 2


## How many bars are drawn.
func bar_count() -> int:
	return _bars


## Where bar `index` is drawn (world, its centre).
func drawn_position(index: int) -> Vector3:
	return _positions[index]


## The width of bar `index`'s fill, in cells.
func drawn_fill_width(index: int) -> float:
	return _fill_widths[index]
