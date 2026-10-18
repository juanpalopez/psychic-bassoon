## The diorama ground's colours (docs/art/STYLE.md, starting palette), which the terrain
## builders bake into vertex colours. The look-dev values; the shaders in this folder light them.
class_name TerrainPalette
extends RefCounted

## Grass: lit, dry and in shade.
const GRASS := Color("6f8f3a")
const GRASS_DRY := Color("a39a52")
const GRASS_SHADE := Color("4a6a2c")
## The forest floor (darker, cooler grass), dirt beside the road and grey-brown stone.
const FOREST_FLOOR := Color("3f5f2a")
const DIRT := Color("9a7444")
const STONE := Color("9b8b78")
## The cliffs: kraft card, its dark layers, the soil lip and the grass at the top of the lip.
const KRAFT := Color("b9773c")
const KRAFT_DARK := Color("5a3418")
const SOIL := Color("3e2b1c")
const LIP_GRASS := Color("7b8a35")
## The floor of the gorge under the water.
const GORGE_BED := Color("4a3a2a")
## The road bed (#325): sand and its worn edge, the joints between its flagstones and the
## paper lip's outer face. `RoadBedBuilder` hands them to `road_bed.gdshader`.
const ROAD := Color("d9b98a")
const ROAD_EDGE := Color("b89262")
const ROAD_JOINT := Color("a5824f")
const ROAD_LIP := Color("8f6b42")
## The bridges: planks, posts, rope and trestle legs.
const PLANK := Color("b88a55")
const PLANK_DARK := Color("8a6a45")
const POST := Color("8f6a40")
const ROPE := Color("8a6a45")
const TRESTLE := Color("9c7647")
