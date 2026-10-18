// The diorama's ground until #327's painted paper lands (#324): the terraces, cliffs and road
// beds, coloured by their vertex colours (rgb in linear light, alpha the baked contact shading
// at the foot of a cliff). Soft warm and cool light: the sun wraps round a face and warms it,
// the side it does not reach is filled cool; matte card with fibre and a broad painted wash in
// the albedo, and corrugated flutes across the walls. Fades into the haze past the map.
// Nothing reads the screen, so Forward+, Mobile and Compatibility draw it alike.
shader_type spatial;

#include "res://render/paper/haze.gdshaderinc"

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
// STYLE.md: sun #ffd9a8 and sky #b9cbe0.
uniform vec3 light_warm : source_color = vec3(1.0, 0.851, 0.659);
uniform vec3 shade_cool : source_color = vec3(0.725, 0.796, 0.878);
uniform float warmth : hint_range(0.0, 1.0) = 0.15;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
uniform float shade_fill : hint_range(0.0, 1.0) = 0.3;
uniform float shade_bounce : hint_range(0.0, 1.0) = 0.35;
uniform float fibre : hint_range(0.0, 0.5) = 0.1;
uniform float wash : hint_range(0.0, 0.5) = 0.12;
// How much of the baked contact shading shows.
uniform float contact : hint_range(0.0, 1.0) = 0.85;
// The corrugation across a wall: metres from flute to flute, and how dark a flute's trough is.
uniform float flute_spacing = 0.09;
uniform float flute_depth : hint_range(0.0, 0.5) = 0.14;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec2 plane = world_position.xz + vec2(world_position.y * 0.7);
	float grain = texture(paper_noise, plane * 1.1).r;
	float broad = texture(paper_noise, world_position.xz * 0.06).g;
	base *= (1.0 - fibre) + 2.0 * fibre * grain;
	base *= (1.0 - wash) + 2.0 * wash * broad;
	float wall = 1.0 - abs(world_normal.y);
	if (wall > 0.2) {
		vec2 along_dir = normalize(vec2(-world_normal.z, world_normal.x) + vec2(1e-5));
		float along = dot(world_position.xz, along_dir);
		float flute = 0.5 + 0.5 * cos(along * 6.2831853 / flute_spacing);
		base *= 1.0 - flute_depth * flute * smoothstep(0.2, 0.6, wall);
	}
	ALBEDO = base * mix(1.0, COLOR.a, contact);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	HAZE_FOG(world_position)
}

void light() {
	float wrapped = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	wrapped = wrapped * wrapped * (3.0 - 2.0 * wrapped);
	vec3 warm = mix(vec3(1.0), light_warm, warmth);
	float sun = wrapped * ATTENUATION;
	DIFFUSE_LIGHT += sun * LIGHT_COLOR * warm / PI;
	// the cool sky fills what the sun does not reach, cast shadows included, a little warmed
	// by the bounce so shade reads as cool paper, not grey
	vec3 fill = mix(shade_cool, light_warm, shade_bounce);
	DIFFUSE_LIGHT += (1.0 - sun) * shade_fill * fill * LIGHT_COLOR / PI;
}
