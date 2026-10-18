// Paper props with their colours in the vertex colours (one surface, so one draw call a
// prop), in the painted paper of painted.gdshaderinc. Vertex alpha marks the faces that glow
// from inside (the Heartstone's heart), so these props take their contact shading from the
// foot of the model only.
shader_type spatial;
render_mode cull_disabled;

#include "res://render/paper/painted.gdshaderinc"

uniform float glow = 0.9;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	PAINTED_PAPER(COLOR.rgb, 1.0)
	EMISSION = COLOR.rgb * COLOR.a * glow;
}
