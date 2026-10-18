// The white pencil circle etched round a socket. `glow` lets the board flash it. Painted paper
// (painted.gdshaderinc).
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"

uniform vec3 pencil_a : source_color = vec3(0.62, 0.62, 0.60);
uniform vec3 pencil_b : source_color = vec3(0.74, 0.74, 0.72);
uniform float glow = 0.0;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	float streak = texture(paper_noise, vec2(UV.x * 0.5, UV.y * 0.05)).r;
	PAINTED_PAPER(mix(pencil_a, pencil_b, streak), 1.0, 0.0)
	EMISSION = vec3(glow);
}
