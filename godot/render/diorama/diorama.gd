## The world the game is played in (#324, docs/art/STYLE.md): a papercraft diorama of the
## valley built from the map at load time, with no table and no edge.
##
## `build` makes the `TerrainField` from the map (the sim's terraces, the river's gorge, and
## render-only country past the map) and runs each builder in its slot, in order. Each builder
## is a child node that owns what it draws and reads only the field:
##
## - `Terraces`: the terrace tops and the corrugated cliffs (`TerraceBuilder`), in chunks;
## - `Water`: the river in its gorge (`WaterBuilder`), in chunks;
## - `RoadBeds`: the road beds and the bridges (a placeholder `PlaceholderRoadBed` until #325);
## - `Scatter`: the forests, rocks, dirt and grass (a placeholder `PlaceholderScatter` until #326).
##
## Plug a builder in with `use_builder("RoadBeds", builder)` (any `DioramaBuilder`); it is built
## at once if the field exists, and on every later `build`. The ground's look is
## `ground_material` (a vertex-colour material: rgb the colour in linear light, alpha the baked
## contact shading), so #327's painted paper swaps in with one assignment before `build`.
@tool
class_name Diorama
extends Node3D

const SLOTS: Array[String] = ["Terraces", "Water", "RoadBeds", "Scatter"]

## The material of the terraces and the road beds, and of the water.
var ground_material: Material = PaperLook.material("terrain_vc")
var water_material: Material = PaperLook.material("water")
## The field of the last build, or null before the first.
var field: TerrainField

var _builders := {}


func _init() -> void:
	use_builder("Terraces", TerraceBuilder.new())
	use_builder("Water", WaterBuilder.new())
	use_builder("RoadBeds", PlaceholderRoadBed.new())
	use_builder("Scatter", PlaceholderScatter.new())


## Builds the diorama for a map, replacing the last one. `routes` are the lines foes walk (the
## game's `routes`); without them the field makes them from the map's cells.
func build(map: GameMap, routes: Array[Route] = []) -> void:
	field = TerrainField.from_map(map, routes)
	for slot in SLOTS:
		_build_slot(slot)


## Puts `builder` in a slot (one of `SLOTS`), freeing the one there before.
func use_builder(slot: String, builder: DioramaBuilder) -> void:
	assert(slot in SLOTS, "no diorama slot %s" % slot)
	if _builders.has(slot):
		var old: DioramaBuilder = _builders[slot]
		remove_child(old)
		old.queue_free()
	builder.name = slot
	_builders[slot] = builder
	add_child(builder)
	# keep the children in slot order, so the scene tree reads like the list above
	var index := 0
	for name_in_order in SLOTS:
		if _builders.has(name_in_order):
			move_child(_builders[name_in_order], index)
			index += 1
	if field != null:
		_build_slot(slot)


## The builder in a slot.
func builder(slot: String) -> DioramaBuilder:
	return _builders.get(slot)


## The triangles every builder drew in the last build (all of them, not only those in view).
func triangle_count() -> int:
	var total := 0
	for slot in _builders:
		total += (_builders[slot] as DioramaBuilder).triangles
	return total


## The surfaces every builder drew (one draw call each per pass, before culling).
func surface_count() -> int:
	var total := 0
	for slot in _builders:
		total += (_builders[slot] as DioramaBuilder).surfaces
	return total


func _build_slot(slot: String) -> void:
	var part: DioramaBuilder = _builders[slot]
	if "material" in part:
		part.set("material", water_material if slot == "Water" else ground_material)
	part.build(field)
