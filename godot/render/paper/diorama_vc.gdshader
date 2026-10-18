// The diorama's generated props (#325 bridges, #326 scatter): faceted card with its colours in
// the vertex colours (linear light, times the MultiMesh instance colour, which Godot multiplies
// into COLOR), in the painted paper every lit surface shares (painted.gdshaderinc), fading into
// the haze past the map like the terrain (haze.gdshaderinc). One surface a prop, so one draw
// call a prop type. Closed models: the back faces are culled.
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"
#include "res://render/paper/haze.gdshaderinc"

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	PAINTED_PAPER(COLOR.rgb, 1.0, 0.0)
	HAZE_FOG(painted_world)
}
