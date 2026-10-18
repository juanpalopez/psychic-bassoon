// The diorama's ground (#324): the terraces, cliffs and road beds in the painted paper of
// painted.gdshaderinc, coloured by their vertex colours (rgb in linear light, alpha the
// contact shading baked at the foot of a cliff), with corrugated flutes across the cliff
// walls, fading into the haze past the map.
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"
#include "res://render/paper/haze.gdshaderinc"

// The corrugation across a wall: metres from flute to flute, and how dark a flute's trough is.
uniform float flute_spacing = 0.09;
uniform float flute_depth : hint_range(0.0, 0.5) = 0.14;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	vec3 base = COLOR.rgb;
	float wall = 1.0 - abs(painted_up.y);
	if (wall > 0.2) {
		vec2 along_dir = normalize(vec2(-painted_up.z, painted_up.x) + vec2(1e-5));
		float along = dot(painted_world.xz, along_dir);
		float flute = 0.5 + 0.5 * cos(along * 6.2831853 / flute_spacing);
		base *= 1.0 - flute_depth * flute * smoothstep(0.2, 0.6, wall);
	}
	PAINTED_PAPER(base, COLOR.a, 0.0)
	HAZE_FOG(painted_world)
}
