// Plain coloured paper (an imported material's colour, such as a foe's or a bridge's): the
// painted paper of painted.gdshaderinc in `colour`. The vertex colour multiplies it, so a
// MultiMesh's instance colour tints it (a hurt foe is drawn darker); a model without vertex
// colours reads white there. `glow` lights it from inside in its own colour (dimmed the same
// way).
shader_type spatial;
render_mode cull_disabled;

// the foes wear this look and walk: the fibre stays on the model
#define PAINTED_OBJECT_SPACE
#include "res://render/paper/painted.gdshaderinc"

uniform vec3 colour : source_color = vec3(0.8, 0.78, 0.72);
uniform float glow = 0.0;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	PAINTED_PAPER(colour * COLOR.rgb, 1.0, 0.0)
	EMISSION = colour * COLOR.rgb * glow;
}
